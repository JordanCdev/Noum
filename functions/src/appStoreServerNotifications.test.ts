import assert from "node:assert/strict";
import test from "node:test";
import {
  Environment,
  NotificationTypeV2,
  OfferDiscountType,
  Subtype,
  type JWSRenewalInfoDecodedPayload,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library";
import {
  APP_STORE_LIFECYCLE_EVENT_NAMES,
  APP_STORE_NOTIFICATION_BUNDLE_ID,
  APP_STORE_NOTIFICATION_PRODUCT_IDS,
  AppStoreNotificationProcessingError,
  appStoreNotificationHTTPStatus,
  appStoreNotificationDigest,
  appStoreSignedPayload,
  parseAppStoreNotificationConfiguration,
  verifyAndProjectAppStoreNotification,
  type AppStoreNotificationConfiguration,
  type AppStoreNotificationVerifier,
  type AppStoreLifecycleProjection,
} from "./appStoreServerNotifications.js";

const now = Date.UTC(2026, 6, 21, 12, 0, 0);
const notificationUUID = "d9428888-122b-4a4b-9e76-9f0b4295f74e";
const outerJWS = `${"a".repeat(64)}.${"b".repeat(64)}.${"c".repeat(64)}`;

const config: AppStoreNotificationConfiguration = {
  environment: Environment.PRODUCTION,
  environmentLabel: "production",
  bundleID: APP_STORE_NOTIFICATION_BUNDLE_ID,
  appAppleID: 123456789,
  rootCertificates: [],
};

test("permanent invalid payloads are acknowledged without a retry", () => {
  assert.equal(
    appStoreNotificationHTTPStatus(
      new AppStoreNotificationProcessingError("verification-failed", false)
    ),
    204
  );
});

test("transient notification failures remain retryable", () => {
  assert.equal(
    appStoreNotificationHTTPStatus(
      new AppStoreNotificationProcessingError(
        "verification-retryable",
        true
      )
    ),
    503
  );
});

/**
 * Returns one production notification envelope from Apple's verifier.
 * @param {NotificationTypeV2|string} type Notification type.
 * @param {Subtype|string} subtype Notification subtype.
 * @return {ResponseBodyV2DecodedPayload} Verified outer fixture.
 */
function notification(
  type: NotificationTypeV2 | string = NotificationTypeV2.SUBSCRIBED,
  subtype: Subtype | string = Subtype.INITIAL_BUY
): ResponseBodyV2DecodedPayload {
  return {
    notificationType: type,
    subtype,
    notificationUUID,
    version: "2.0",
    signedDate: now - 10_000,
    data: {
      environment: Environment.PRODUCTION,
      appAppleId: 123456789,
      bundleId: APP_STORE_NOTIFICATION_BUNDLE_ID,
      signedTransactionInfo: "verified-transaction-jws",
      signedRenewalInfo: "verified-renewal-jws",
    },
  };
}

/**
 * Returns decoded transaction metadata with deliberately sensitive IDs.
 * @return {JWSTransactionDecodedPayload} Verified transaction fixture.
 */
function transaction(): JWSTransactionDecodedPayload {
  return {
    bundleId: APP_STORE_NOTIFICATION_BUNDLE_ID,
    environment: Environment.PRODUCTION,
    offerDiscountType: OfferDiscountType.FREE_TRIAL,
    productId: APP_STORE_NOTIFICATION_PRODUCT_IDS.annual,
    transactionId: "sensitive-transaction-id",
    originalTransactionId: "sensitive-original-id",
    appAccountToken: "deleted-account-token",
  };
}

/**
 * Returns decoded renewal metadata with deliberately sensitive IDs.
 * @return {JWSRenewalInfoDecodedPayload} Verified renewal fixture.
 */
function renewal(): JWSRenewalInfoDecodedPayload {
  return {
    environment: Environment.PRODUCTION,
    productId: APP_STORE_NOTIFICATION_PRODUCT_IDS.annual,
    autoRenewProductId: APP_STORE_NOTIFICATION_PRODUCT_IDS.annual,
    originalTransactionId: "sensitive-original-id",
    appAccountToken: "deleted-account-token",
  };
}

/** Injectable verifier that returns already-verified decoded fixtures. */
class FakeVerifier implements AppStoreNotificationVerifier {
  outer: ResponseBodyV2DecodedPayload = notification();
  decodedTransaction: JWSTransactionDecodedPayload = transaction();
  decodedRenewal: JWSRenewalInfoDecodedPayload = renewal();
  outerFailure: Error | null = null;
  transactionFailure: Error | null = null;
  renewalFailure: Error | null = null;
  calls: string[] = [];

  /** @return {Promise<ResponseBodyV2DecodedPayload>} Outer fixture. */
  async verifyAndDecodeNotification():
  Promise<ResponseBodyV2DecodedPayload> {
    this.calls.push("outer");
    if (this.outerFailure) throw this.outerFailure;
    return this.outer;
  }

  /** @return {Promise<JWSTransactionDecodedPayload>} Transaction fixture. */
  async verifyAndDecodeTransaction():
  Promise<JWSTransactionDecodedPayload> {
    this.calls.push("transaction");
    if (this.transactionFailure) throw this.transactionFailure;
    return this.decodedTransaction;
  }

  /** @return {Promise<JWSRenewalInfoDecodedPayload>} Renewal fixture. */
  async verifyAndDecodeRenewalInfo():
  Promise<JWSRenewalInfoDecodedPayload> {
    this.calls.push("renewal");
    if (this.renewalFailure) throw this.renewalFailure;
    return this.decodedRenewal;
  }
}

/** Minimal in-memory idempotent sink mirroring the Firestore transaction. */
class FakeProjectionSink {
  private readonly markers = new Set<string>();
  writes: AppStoreLifecycleProjection[] = [];

  /**
   * Records one unique projection.
   * @param {AppStoreLifecycleProjection} projection Candidate projection.
   * @return {boolean} True for a duplicate marker.
   */
  record(projection: AppStoreLifecycleProjection): boolean {
    if (this.markers.has(projection.notificationDigest)) return true;
    this.markers.add(projection.notificationDigest);
    this.writes.push(projection);
    return false;
  }
}

test("request accepts only one bounded signedPayload field", () => {
  assert.equal(appStoreSignedPayload({signedPayload: outerJWS}), outerJWS);
  for (const body of [
    null,
    {},
    {signedPayload: "a.b.c"},
    {signedPayload: outerJWS, receipt: "private"},
    {signedPayload: `${"a".repeat(64_001)}.b.c`},
  ]) {
    assert.throws(
      () => appStoreSignedPayload(body),
      (error) => error instanceof AppStoreNotificationProcessingError &&
        error.code === "request-malformed" && !error.retryable
    );
  }
});

test("receiver configuration is disabled and invalid by default", () => {
  assert.throws(
    () => parseAppStoreNotificationConfiguration({
      enabled: "false",
      appAppleID: "123456789",
      rootCertificatesBase64: "[]",
      environment: Environment.PRODUCTION,
    }),
    (error) => error instanceof AppStoreNotificationProcessingError &&
      error.code === "configuration-disabled" && error.retryable
  );
  assert.throws(
    () => parseAppStoreNotificationConfiguration({
      enabled: "true",
      appAppleID: "123456789",
      rootCertificatesBase64: "[]",
      environment: Environment.PRODUCTION,
    }),
    (error) => error instanceof AppStoreNotificationProcessingError &&
      error.code === "configuration-invalid" && error.retryable
  );
});

test("verified free-trial purchase produces bounded facts", async () => {
  const verifier = new FakeVerifier();
  const projection = await verifyAndProjectAppStoreNotification(
    outerJWS, verifier, config, now
  );
  assert.deepEqual(verifier.calls, ["outer", "transaction", "renewal"]);
  assert.deepEqual(projection.eventCounts, {
    [APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementActivated]: 1,
    [APP_STORE_LIFECYCLE_EVENT_NAMES.trialStarted]: 1,
  });
  assert.equal(projection.periodKey, "2026-07-21");
  assert.equal(projection.environment, "production");
  assert.match(projection.notificationDigest, /^[0-9a-f]{64}$/u);
});

test("exact monthly and annual Noum products are accepted", async () => {
  assert.deepEqual(APP_STORE_NOTIFICATION_PRODUCT_IDS, {
    monthly: "com.noum.pro.monthly",
    annual: "com.noum.pro.annual",
  });

  for (const productId of Object.values(APP_STORE_NOTIFICATION_PRODUCT_IDS)) {
    const verifier = new FakeVerifier();
    verifier.decodedTransaction.productId = productId;
    verifier.decodedRenewal.productId = productId;
    verifier.decodedRenewal.autoRenewProductId = productId;

    const projection = await verifyAndProjectAppStoreNotification(
      outerJWS, verifier, config, now
    );

    assert.equal(
      projection.eventCounts[
        APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementActivated
      ],
      1,
      productId
    );
  }
});

test("present product metadata is required and exact", async () => {
  const cases: Array<[
    string,
    (verifier: FakeVerifier) => void
  ]> = [
    ["missing transaction product", (verifier) => {
      delete verifier.decodedTransaction.productId;
    }],
    ["unknown transaction product", (verifier) => {
      verifier.decodedTransaction.productId = "com.attacker.pro.annual";
    }],
    ["lookalike transaction product", (verifier) => {
      verifier.decodedTransaction.productId =
        `${APP_STORE_NOTIFICATION_PRODUCT_IDS.annual}.forged`;
    }],
    ["missing current renewal product", (verifier) => {
      delete verifier.decodedRenewal.productId;
    }],
    ["unknown current renewal product", (verifier) => {
      verifier.decodedRenewal.productId = "com.attacker.pro.annual";
    }],
    ["missing next renewal product", (verifier) => {
      delete verifier.decodedRenewal.autoRenewProductId;
    }],
    ["unknown next renewal product", (verifier) => {
      verifier.decodedRenewal.autoRenewProductId =
        "com.attacker.pro.monthly";
    }],
  ];

  for (const [label, mutate] of cases) {
    const verifier = new FakeVerifier();
    mutate(verifier);
    await assert.rejects(
      verifyAndProjectAppStoreNotification(outerJWS, verifier, config, now),
      (error) => error instanceof AppStoreNotificationProcessingError &&
        error.code === "verified-payload-invalid" && !error.retryable,
      label
    );
  }
});

test(
  "mixed transaction and renewal products reject " +
    "a tampered member",
  async () => {
    const cases: Array<[
      string,
      (verifier: FakeVerifier) => void
    ]> = [
      ["tampered transaction", (verifier) => {
        verifier.decodedTransaction.productId = "com.attacker.pro.monthly";
        verifier.decodedRenewal.productId =
          APP_STORE_NOTIFICATION_PRODUCT_IDS.annual;
        verifier.decodedRenewal.autoRenewProductId =
          APP_STORE_NOTIFICATION_PRODUCT_IDS.monthly;
      }],
      ["tampered renewal", (verifier) => {
        verifier.decodedTransaction.productId =
          APP_STORE_NOTIFICATION_PRODUCT_IDS.annual;
        verifier.decodedRenewal.productId =
          APP_STORE_NOTIFICATION_PRODUCT_IDS.annual;
        verifier.decodedRenewal.autoRenewProductId =
          "com.attacker.pro.monthly";
      }],
    ];

    for (const [label, mutate] of cases) {
      const verifier = new FakeVerifier();
      mutate(verifier);
      await assert.rejects(
        verifyAndProjectAppStoreNotification(outerJWS, verifier, config, now),
        (error) => error instanceof AppStoreNotificationProcessingError &&
          error.code === "verified-payload-invalid",
        label
      );
    }
  }
);

test("a valid monthly to annual renewal transition is accepted", async () => {
  const verifier = new FakeVerifier();
  verifier.decodedTransaction.productId =
    APP_STORE_NOTIFICATION_PRODUCT_IDS.monthly;
  verifier.decodedRenewal.productId =
    APP_STORE_NOTIFICATION_PRODUCT_IDS.monthly;
  verifier.decodedRenewal.autoRenewProductId =
    APP_STORE_NOTIFICATION_PRODUCT_IDS.annual;

  const projection = await verifyAndProjectAppStoreNotification(
    outerJWS, verifier, config, now
  );

  assert.equal(
    projection.eventCounts[
      APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementActivated
    ],
    1
  );
});

test("a renewal-only lifecycle event may omit transaction info", async () => {
  const verifier = new FakeVerifier();
  verifier.outer = notification(
    NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS,
    Subtype.AUTO_RENEW_DISABLED
  );
  delete verifier.outer.data!.signedTransactionInfo;

  const projection = await verifyAndProjectAppStoreNotification(
    outerJWS, verifier, config, now
  );

  assert.deepEqual(verifier.calls, ["outer", "renewal"]);
  assert.deepEqual(projection.eventCounts, {
    [APP_STORE_LIFECYCLE_EVENT_NAMES.cancellationRequested]: 1,
  });
});

test("forged outer or nested JWS never reaches the sink", async () => {
  for (const failedLayer of ["outer", "transaction", "renewal"] as const) {
    const verifier = new FakeVerifier();
    if (failedLayer === "outer") verifier.outerFailure = new Error("forged");
    if (failedLayer === "transaction") {
      verifier.transactionFailure = new Error("forged");
    }
    if (failedLayer === "renewal") {
      verifier.renewalFailure = new Error("forged");
    }
    await assert.rejects(
      verifyAndProjectAppStoreNotification(outerJWS, verifier, config, now),
      (error) => error instanceof AppStoreNotificationProcessingError &&
        error.code === "verification-failed" && !error.retryable,
      failedLayer
    );
  }
});

test("wrong verified app identity and environment fail closed", async () => {
  const mutations: Array<(verifier: FakeVerifier) => void> = [
    (verifier) => {
      verifier.outer.data!.bundleId = "com.attacker.lookalike";
    },
    (verifier) => {
      verifier.outer.data!.appAppleId = 999;
    },
    (verifier) => {
      verifier.outer.data!.environment = Environment.SANDBOX;
    },
    (verifier) => {
      verifier.decodedTransaction.bundleId = "com.attacker.lookalike";
    },
    (verifier) => {
      verifier.decodedRenewal.environment = Environment.SANDBOX;
    },
  ];
  for (const mutate of mutations) {
    const verifier = new FakeVerifier();
    mutate(verifier);
    await assert.rejects(
      verifyAndProjectAppStoreNotification(outerJWS, verifier, config, now),
      (error) => error instanceof AppStoreNotificationProcessingError &&
        error.code === "verified-payload-invalid"
    );
  }
});

test("malformed envelope and missing nested proofs fail closed", async () => {
  const mutations: Array<(verifier: FakeVerifier) => void> = [
    (verifier) => {
      verifier.outer.notificationUUID = "not-a-uuid";
    },
    (verifier) => {
      verifier.outer.version = "1.0";
    },
    (verifier) => {
      verifier.outer.signedDate = now + 600_000;
    },
    (verifier) => {
      delete verifier.outer.data!.signedTransactionInfo;
    },
    (verifier) => {
      delete verifier.outer.data!.signedRenewalInfo;
    },
  ];
  for (const mutate of mutations) {
    const verifier = new FakeVerifier();
    mutate(verifier);
    await assert.rejects(
      verifyAndProjectAppStoreNotification(outerJWS, verifier, config, now),
      (error) => error instanceof AppStoreNotificationProcessingError &&
        error.code === "verified-payload-invalid"
    );
  }
});

test("lifecycle notification types map once", async () => {
  const cases: Array<[
    NotificationTypeV2,
    Subtype,
    string
  ]> = [
    [
      NotificationTypeV2.DID_RENEW,
      Subtype.BILLING_RECOVERY,
      APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementRenewed,
    ],
    [
      NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS,
      Subtype.AUTO_RENEW_DISABLED,
      APP_STORE_LIFECYCLE_EVENT_NAMES.cancellationRequested,
    ],
    [
      NotificationTypeV2.DID_FAIL_TO_RENEW,
      Subtype.BILLING_RETRY,
      APP_STORE_LIFECYCLE_EVENT_NAMES.billingFailed,
    ],
    [
      NotificationTypeV2.REFUND,
      Subtype.VOLUNTARY,
      APP_STORE_LIFECYCLE_EVENT_NAMES.purchaseRefunded,
    ],
    [
      NotificationTypeV2.EXPIRED,
      Subtype.VOLUNTARY,
      APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementExpired,
    ],
    [
      NotificationTypeV2.REVOKE,
      Subtype.VOLUNTARY,
      APP_STORE_LIFECYCLE_EVENT_NAMES.entitlementBecameInactive,
    ],
  ];
  for (const [type, subtype, eventName] of cases) {
    const verifier = new FakeVerifier();
    verifier.outer = notification(type, subtype);
    const projection = await verifyAndProjectAppStoreNotification(
      outerJWS, verifier, config, now
    );
    assert.deepEqual(projection.eventCounts, {[eventName]: 1}, type);
  }
});

test("verified unknown and test notifications are ignored", async () => {
  for (const type of ["FUTURE_APPLE_EVENT", NotificationTypeV2.TEST]) {
    const verifier = new FakeVerifier();
    verifier.outer = notification(type, "FUTURE_SUBTYPE");
    delete verifier.outer.data!.signedTransactionInfo;
    delete verifier.outer.data!.signedRenewalInfo;
    const projection = await verifyAndProjectAppStoreNotification(
      outerJWS, verifier, config, now
    );
    assert.deepEqual(projection.eventCounts, {});
  }
});

test("one-way marker makes an identical Apple retry idempotent", async () => {
  const verifier = new FakeVerifier();
  const projection = await verifyAndProjectAppStoreNotification(
    outerJWS, verifier, config, now
  );
  const sink = new FakeProjectionSink();
  assert.equal(sink.record(projection), false);
  assert.equal(sink.record(projection), true);
  assert.equal(sink.writes.length, 1);
  assert.equal(
    projection.notificationDigest,
    appStoreNotificationDigest(notificationUUID.toUpperCase())
  );
  assert.notEqual(projection.notificationDigest, notificationUUID);
});

test("account identifiers and StoreKit details never persist", async () => {
  const verifier = new FakeVerifier();
  const projection = await verifyAndProjectAppStoreNotification(
    outerJWS, verifier, config, now
  );
  const stored = JSON.stringify(projection);
  for (const forbidden of [
    "deleted-account-token",
    "sensitive-transaction-id",
    "sensitive-original-id",
    APP_STORE_NOTIFICATION_PRODUCT_IDS.annual,
    "verified-transaction-jws",
    "verified-renewal-jws",
    outerJWS,
    notificationUUID,
    "productId",
    "appAccountToken",
    "transactionId",
  ]) {
    assert.equal(stored.includes(forbidden), false, forbidden);
  }
});

test("notification digest is stable and case-normalized", () => {
  assert.equal(
    appStoreNotificationDigest(notificationUUID),
    appStoreNotificationDigest(notificationUUID.toUpperCase())
  );
});
