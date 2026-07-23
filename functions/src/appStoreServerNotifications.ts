import {
  Environment,
  NotificationTypeV2,
  OfferDiscountType,
  SignedDataVerifier,
  Subtype,
  VerificationException,
  VerificationStatus,
  type JWSRenewalInfoDecodedPayload,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library";
import {createHash, X509Certificate} from "node:crypto";

const DAY_MILLISECONDS = 86_400_000;
const MAXIMUM_FUTURE_SKEW_MILLISECONDS = 5 * 60_000;
const MINIMUM_SIGNED_DATE_MILLISECONDS = Date.UTC(2021, 0, 1);
const MAXIMUM_SIGNED_PAYLOAD_CHARACTERS = 64_000;
const MAXIMUM_ROOT_CERTIFICATES = 4;
const MINIMUM_CERTIFICATE_BYTES = 256;
const MAXIMUM_CERTIFICATE_BYTES = 8_192;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iu;
const JWS_PATTERN = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/u;
const BASE64_PATTERN = new RegExp(
  "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|" +
    "[A-Za-z0-9+/]{3}=)?$",
  "u"
);

export const APP_STORE_NOTIFICATION_BUNDLE_ID = "com.jordancoaten.noum";
export const APP_STORE_NOTIFICATION_PRODUCT_IDS = Object.freeze({
  monthly: "com.noum.pro.monthly",
  annual: "com.noum.pro.annual",
});
export const APP_STORE_NOTIFICATION_MARKER_RETENTION_MILLISECONDS =
  400 * DAY_MILLISECONDS;

const APP_STORE_NOTIFICATION_PRODUCT_ID_ALLOWLIST = new Set<string>(
  Object.values(APP_STORE_NOTIFICATION_PRODUCT_IDS)
);

export const APP_STORE_LIFECYCLE_EVENT_NAMES = Object.freeze({
  trialStarted: "growth.subscription.trialStarted",
  entitlementActivated: "growth.subscription.entitlementActivated",
  entitlementRenewed: "growth.subscription.entitlementRenewed",
  cancellationRequested: "growth.subscription.cancellationRequested",
  billingFailed: "growth.subscription.billingFailed",
  purchaseRefunded: "growth.subscription.purchaseRefunded",
  entitlementExpired: "growth.subscription.entitlementExpired",
  entitlementBecameInactive:
    "growth.subscription.entitlementBecameInactive",
});

export type AppStoreLifecycleEventName =
  typeof APP_STORE_LIFECYCLE_EVENT_NAMES[
    keyof typeof APP_STORE_LIFECYCLE_EVENT_NAMES
  ];

export type AppStoreNotificationEnvironment = "production" | "sandbox";

export interface AppStoreNotificationVerifier {
  verifyAndDecodeNotification(
    signedPayload: string
  ): Promise<ResponseBodyV2DecodedPayload>;
  verifyAndDecodeTransaction(
    signedTransactionInfo: string
  ): Promise<JWSTransactionDecodedPayload>;
  verifyAndDecodeRenewalInfo(
    signedRenewalInfo: string
  ): Promise<JWSRenewalInfoDecodedPayload>;
}

export interface AppStoreNotificationConfiguration {
  environment: Environment.PRODUCTION | Environment.SANDBOX;
  environmentLabel: AppStoreNotificationEnvironment;
  bundleID: typeof APP_STORE_NOTIFICATION_BUNDLE_ID;
  appAppleID?: number;
  rootCertificates: Buffer[];
}

export interface AppStoreLifecycleProjection {
  schemaVersion: 1;
  source: "appStoreServerNotificationsV2";
  environment: AppStoreNotificationEnvironment;
  notificationDigest: string;
  periodKey: string;
  periodStartMilliseconds: number;
  periodEndMilliseconds: number;
  eventCounts: Partial<Record<AppStoreLifecycleEventName, 1>>;
}

export type AppStoreNotificationFailureCode =
  | "configuration-disabled"
  | "configuration-invalid"
  | "request-malformed"
  | "verification-failed"
  | "verification-retryable"
  | "verified-payload-invalid";

/** Stable content-free processing failure returned by the receiver. */
export class AppStoreNotificationProcessingError extends Error {
  readonly code: AppStoreNotificationFailureCode;
  readonly retryable: boolean;

  /**
   * Creates a safe processing error.
   * @param {AppStoreNotificationFailureCode} code Stable failure reason.
   * @param {boolean} retryable Whether Apple should retry.
   */
  constructor(
    code: AppStoreNotificationFailureCode,
    retryable: boolean
  ) {
    super(code);
    this.name = "AppStoreNotificationProcessingError";
    this.code = code;
    this.retryable = retryable;
  }
}

/**
 * Maps a bounded processing failure to Apple's Version 2 response contract.
 * Apple retries both 4xx and 5xx responses, so permanently invalid payloads
 * are acknowledged with a no-content 2xx only after the handler has declined
 * to write them. Transient verification/configuration/storage failures remain
 * retryable.
 * @param {AppStoreNotificationProcessingError} error Bounded failure.
 * @return {204|503} Stable no-write acknowledgement or retry signal.
 */
export function appStoreNotificationHTTPStatus(
  error: AppStoreNotificationProcessingError
): 204 | 503 {
  return error.retryable ? 503 : 204;
}

/**
 * Fails without including a submitted value in the error.
 * @param {AppStoreNotificationFailureCode} code Stable failure reason.
 * @param {boolean} retryable Whether Apple should retry the notification.
 */
function fail(
  code: AppStoreNotificationFailureCode,
  retryable: boolean
): never {
  throw new AppStoreNotificationProcessingError(code, retryable);
}

/**
 * Returns true for a plain JSON object.
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Accepts only Apple's one-field V2 HTTP request body.
 * @param {unknown} body Parsed request body.
 * @return {string} Bounded signed JWS.
 */
export function appStoreSignedPayload(body: unknown): string {
  if (!isRecord(body) || Object.keys(body).length !== 1 ||
      typeof body.signedPayload !== "string" ||
      body.signedPayload.length < 64 ||
      body.signedPayload.length > MAXIMUM_SIGNED_PAYLOAD_CHARACTERS ||
      !JWS_PATTERN.test(body.signedPayload)) {
    return fail("request-malformed", false);
  }
  return body.signedPayload;
}

/**
 * Parses the public Apple roots and exact production identity fail closed.
 * @param {object} input Environment-backed configuration.
 * @param {string} input.enabled Exact feature switch.
 * @param {string|undefined} input.appAppleID App Store numeric app ID.
 * @param {string} input.rootCertificatesBase64 JSON array of DER roots.
 * @param {Environment.PRODUCTION|Environment.SANDBOX} input.environment Target.
 * @return {AppStoreNotificationConfiguration} Verified constructor inputs.
 */
export function parseAppStoreNotificationConfiguration(input: {
  enabled: string;
  appAppleID?: string;
  rootCertificatesBase64: string;
  environment: Environment.PRODUCTION | Environment.SANDBOX;
}): AppStoreNotificationConfiguration {
  if (input.enabled !== "true") {
    return fail("configuration-disabled", true);
  }

  let rawCertificates: unknown;
  try {
    rawCertificates = JSON.parse(input.rootCertificatesBase64);
  } catch {
    return fail("configuration-invalid", true);
  }
  if (!Array.isArray(rawCertificates) || rawCertificates.length < 1 ||
      rawCertificates.length > MAXIMUM_ROOT_CERTIFICATES ||
      rawCertificates.some((value) =>
        typeof value !== "string" || !BASE64_PATTERN.test(value)
      )) {
    return fail("configuration-invalid", true);
  }

  const fingerprints = new Set<string>();
  const rootCertificates: Buffer[] = [];
  try {
    for (const encoded of rawCertificates as string[]) {
      const certificate = Buffer.from(encoded, "base64");
      if (certificate.length < MINIMUM_CERTIFICATE_BYTES ||
          certificate.length > MAXIMUM_CERTIFICATE_BYTES ||
          certificate.toString("base64") !== encoded) {
        return fail("configuration-invalid", true);
      }
      const parsed = new X509Certificate(certificate);
      if (fingerprints.has(parsed.fingerprint256)) {
        return fail("configuration-invalid", true);
      }
      fingerprints.add(parsed.fingerprint256);
      rootCertificates.push(certificate);
    }
  } catch (error) {
    if (error instanceof AppStoreNotificationProcessingError) throw error;
    return fail("configuration-invalid", true);
  }

  let appAppleID: number | undefined;
  if (input.environment === Environment.PRODUCTION) {
    if (typeof input.appAppleID !== "string" ||
        !/^[1-9][0-9]{0,15}$/u.test(input.appAppleID)) {
      return fail("configuration-invalid", true);
    }
    appAppleID = Number(input.appAppleID);
    if (!Number.isSafeInteger(appAppleID)) {
      return fail("configuration-invalid", true);
    }
  }

  return {
    environment: input.environment,
    environmentLabel: input.environment === Environment.PRODUCTION ?
      "production" : "sandbox",
    bundleID: APP_STORE_NOTIFICATION_BUNDLE_ID,
    appAppleID,
    rootCertificates,
  };
}

/**
 * Creates Apple's official cryptographic verifier from reviewed config.
 * @param {AppStoreNotificationConfiguration} configuration Exact config.
 * @return {AppStoreNotificationVerifier} Official App Store verifier.
 */
export function createAppStoreNotificationVerifier(
  configuration: AppStoreNotificationConfiguration
): AppStoreNotificationVerifier {
  return new SignedDataVerifier(
    configuration.rootCertificates,
    true,
    configuration.environment,
    configuration.bundleID,
    configuration.appAppleID
  );
}

/**
 * Converts a server-owned notification UUID to a one-way replay marker.
 * @param {string} notificationUUID Verified Apple notification UUID.
 * @return {string} Domain-separated SHA-256 digest.
 */
export function appStoreNotificationDigest(notificationUUID: string): string {
  return createHash("sha256")
    .update("noum-app-store-server-notification-v2\0", "utf8")
    .update(notificationUUID.toLowerCase(), "utf8")
    .digest("hex");
}

/**
 * Requires the decoded envelope to retain the verifier's exact app identity.
 * @param {ResponseBodyV2DecodedPayload} payload Verified outer payload.
 * @param {AppStoreNotificationConfiguration} config Expected app identity.
 * @param {number} nowMilliseconds Trusted server wall clock.
 * @return {void} Returns after the exact identity is validated.
 */
function validateVerifiedEnvelope(
  payload: ResponseBodyV2DecodedPayload,
  config: AppStoreNotificationConfiguration,
  nowMilliseconds: number
): asserts payload is ResponseBodyV2DecodedPayload & {
  notificationUUID: string;
  signedDate: number;
  version: string;
  data: NonNullable<ResponseBodyV2DecodedPayload["data"]>;
} {
  if (payload.version !== "2.0" ||
      typeof payload.notificationUUID !== "string" ||
      !UUID_PATTERN.test(payload.notificationUUID) ||
      typeof payload.signedDate !== "number" ||
      !Number.isSafeInteger(payload.signedDate) ||
      payload.signedDate < MINIMUM_SIGNED_DATE_MILLISECONDS ||
      payload.signedDate > nowMilliseconds +
        MAXIMUM_FUTURE_SKEW_MILLISECONDS ||
      !payload.data ||
      payload.data.bundleId !== config.bundleID ||
      payload.data.environment !== config.environment ||
      (config.environment === Environment.PRODUCTION &&
       payload.data.appAppleId !== config.appAppleID)) {
    return fail("verified-payload-invalid", false);
  }
}

/**
 * Checks an independently verified nested transaction without retaining IDs.
 * @param {JWSTransactionDecodedPayload} transaction Verified transaction.
 * @param {AppStoreNotificationConfiguration} config Expected app identity.
 * @return {void} Returns after the exact identity is validated.
 */
function validateTransactionIdentity(
  transaction: JWSTransactionDecodedPayload,
  config: AppStoreNotificationConfiguration
): void {
  if (transaction.bundleId !== config.bundleID ||
      transaction.environment !== config.environment ||
      typeof transaction.productId !== "string" ||
      !APP_STORE_NOTIFICATION_PRODUCT_ID_ALLOWLIST.has(
        transaction.productId
      )) {
    return fail("verified-payload-invalid", false);
  }
}

/**
 * Checks independently verified renewal metadata without retaining IDs.
 * @param {JWSRenewalInfoDecodedPayload} renewal Verified renewal info.
 * @param {AppStoreNotificationConfiguration} config Expected environment.
 * @return {void} Returns after the exact environment is validated.
 */
function validateRenewalIdentity(
  renewal: JWSRenewalInfoDecodedPayload,
  config: AppStoreNotificationConfiguration
): void {
  if (renewal.environment !== config.environment ||
      typeof renewal.productId !== "string" ||
      !APP_STORE_NOTIFICATION_PRODUCT_ID_ALLOWLIST.has(renewal.productId) ||
      typeof renewal.autoRenewProductId !== "string" ||
      !APP_STORE_NOTIFICATION_PRODUCT_ID_ALLOWLIST.has(
        renewal.autoRenewProductId
      )) {
    return fail("verified-payload-invalid", false);
  }
}

const TRANSACTION_REQUIRED_TYPES = new Set<string>([
  NotificationTypeV2.SUBSCRIBED,
  NotificationTypeV2.DID_RENEW,
  NotificationTypeV2.EXPIRED,
  NotificationTypeV2.REFUND,
  NotificationTypeV2.REVOKE,
  NotificationTypeV2.REFUND_REVERSED,
]);

const RENEWAL_REQUIRED_TYPES = new Set<string>([
  NotificationTypeV2.SUBSCRIBED,
  NotificationTypeV2.DID_RENEW,
  NotificationTypeV2.EXPIRED,
  NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS,
  NotificationTypeV2.DID_FAIL_TO_RENEW,
  NotificationTypeV2.GRACE_PERIOD_EXPIRED,
]);

/**
 * Maps verified Apple semantics to Noum's existing bounded lifecycle facts.
 * @param {string|undefined} type Verified notification type.
 * @param {string|undefined} subtype Verified notification subtype.
 * @param {JWSTransactionDecodedPayload|undefined} transaction Transaction.
 * @return {Partial<Record<AppStoreLifecycleEventName, 1>>} Bounded counters.
 */
function lifecycleEventCounts(
  type: string | undefined,
  subtype: string | undefined,
  transaction: JWSTransactionDecodedPayload | undefined
): Partial<Record<AppStoreLifecycleEventName, 1>> {
  const counts: Partial<Record<AppStoreLifecycleEventName, 1>> = {};
  switch (type) {
  case NotificationTypeV2.SUBSCRIBED:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementActivated] = 1;
    if (transaction?.offerDiscountType === OfferDiscountType.FREE_TRIAL) {
      counts[APP_STORE_LIFECYCLE_EVENT_NAMES.trialStarted] = 1;
    }
    break;
  case NotificationTypeV2.DID_RENEW:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementRenewed] = 1;
    break;
  case NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS:
    if (subtype === Subtype.AUTO_RENEW_DISABLED) {
      counts[APP_STORE_LIFECYCLE_EVENT_NAMES.cancellationRequested] = 1;
    }
    break;
  case NotificationTypeV2.DID_FAIL_TO_RENEW:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.billingFailed] = 1;
    break;
  case NotificationTypeV2.REFUND:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.purchaseRefunded] = 1;
    break;
  case NotificationTypeV2.EXPIRED:
  case NotificationTypeV2.GRACE_PERIOD_EXPIRED:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementExpired] = 1;
    break;
  case NotificationTypeV2.REVOKE:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementBecameInactive] = 1;
    break;
  case NotificationTypeV2.REFUND_REVERSED:
    counts[APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementActivated] = 1;
    break;
  default:
    break;
  }
  return counts;
}

/**
 * Verifies the outer and nested Apple JWS objects and returns only anonymous
 * aggregate counters. Raw JWS values and decoded identifiers never cross this
 * projection boundary.
 * @param {string} signedPayload Bounded V2 outer JWS.
 * @param {AppStoreNotificationVerifier} verifier Injectable Apple verifier.
 * @param {AppStoreNotificationConfiguration} config Expected app identity.
 * @param {number} nowMilliseconds Trusted server clock.
 * @return {Promise<AppStoreLifecycleProjection>} Anonymous lifecycle facts.
 */
export async function verifyAndProjectAppStoreNotification(
  signedPayload: string,
  verifier: AppStoreNotificationVerifier,
  config: AppStoreNotificationConfiguration,
  nowMilliseconds: number = Date.now()
): Promise<AppStoreLifecycleProjection> {
  let payload: ResponseBodyV2DecodedPayload;
  try {
    payload = await verifier.verifyAndDecodeNotification(signedPayload);
  } catch (error) {
    const retryable = error instanceof VerificationException &&
      error.status === VerificationStatus.RETRYABLE_VERIFICATION_FAILURE;
    return fail(
      retryable ? "verification-retryable" : "verification-failed",
      retryable
    );
  }
  validateVerifiedEnvelope(payload, config, nowMilliseconds);

  let transaction: JWSTransactionDecodedPayload | undefined;
  let renewal: JWSRenewalInfoDecodedPayload | undefined;
  try {
    if (payload.data.signedTransactionInfo) {
      transaction = await verifier.verifyAndDecodeTransaction(
        payload.data.signedTransactionInfo
      );
      validateTransactionIdentity(transaction, config);
    }
    if (payload.data.signedRenewalInfo) {
      renewal = await verifier.verifyAndDecodeRenewalInfo(
        payload.data.signedRenewalInfo
      );
      validateRenewalIdentity(renewal, config);
    }
  } catch (error) {
    if (error instanceof AppStoreNotificationProcessingError) throw error;
    const retryable = error instanceof VerificationException &&
      error.status === VerificationStatus.RETRYABLE_VERIFICATION_FAILURE;
    return fail(
      retryable ? "verification-retryable" : "verification-failed",
      retryable
    );
  }

  if ((TRANSACTION_REQUIRED_TYPES.has(payload.notificationType ?? "") &&
       !transaction) ||
      (RENEWAL_REQUIRED_TYPES.has(payload.notificationType ?? "") &&
       !renewal)) {
    return fail("verified-payload-invalid", false);
  }

  const periodStartMilliseconds = payload.signedDate -
    (payload.signedDate % DAY_MILLISECONDS);
  return {
    schemaVersion: 1,
    source: "appStoreServerNotificationsV2",
    environment: config.environmentLabel,
    notificationDigest: appStoreNotificationDigest(payload.notificationUUID),
    periodKey: new Date(periodStartMilliseconds).toISOString().slice(0, 10),
    periodStartMilliseconds,
    periodEndMilliseconds: periodStartMilliseconds + DAY_MILLISECONDS,
    eventCounts: lifecycleEventCounts(
      payload.notificationType,
      payload.subtype,
      transaction
    ),
  };
}
