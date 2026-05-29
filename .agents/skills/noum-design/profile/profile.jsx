// Noum · Communication Profile screen
// Premium progress overview. One screen, narrative structure, calm hierarchy.
//
// Visual rules
//  - white cards, 24/28 corner, single soft shadow, no card gradients
//  - color reserved for: hero icon tile, hero number, CTA, status pip
//  - duotone icons in 36px squircle tiles (tint 14% fill, glyph 100%)
//  - section starters use 11px micro-label, no chrome
//
// Motion rules
//  - numbers count up on first reveal (900ms ease-out)
//  - card expand: grid-template-rows 0fr → 1fr (320ms snappy)
//  - bars/rings draw from 0 (700ms snappy)
//  - press: scale(0.97) + opacity(0.85), 260ms

const { useState, useEffect, useRef, useMemo } = React;

const TINT = {
  blue:   '#3378F5',
  green:  '#249970',
  orange: '#F28C26',
  indigo: '#526EF0',
  purple: '#8F47EB',
  amber:  '#D4851A',
  red:    '#BD3833',
  slate:  '#697382',
};

// ───────────────── motion: count-up hook ─────────────────
function useCountUp(target, { decimals = 0, duration = 900, trigger = true } = {}) {
  const [val, setVal] = useState(0);
  useEffect(() => {
    if (!trigger) return;
    // If the document is hidden (screenshot tools, background tabs) RAF is
    // throttled — snap to target so numbers are always correct.
    // Same goes for users who prefer reduced motion.
    const reduceMotion = typeof matchMedia !== 'undefined'
      && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (document.hidden || reduceMotion) {
      setVal(target);
      return;
    }
    const start = performance.now();
    let raf;
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3); // ease-out cubic
      setVal(target * eased);
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, duration, trigger]);
  return decimals === 0 ? Math.round(val) : val.toFixed(decimals);
}

// ───────────────── primitive: squircle icon tile ─────────────────
const IconTile = ({ children, tint = TINT.blue, size = 36, radius = 12 }) => (
  <div style={{
    width: size, height: size, flexShrink: 0,
    borderRadius: radius,
    background: `${tint}1f`,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: tint,
  }}>
    {children}
  </div>
);

// duotone glyph set — rounded stroke, paired with IconTile
const Glyph = ({ name, size = 18, color = 'currentColor' }) => {
  const sw = 1.85;
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: color, strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const fillSoft = { fill: color, fillOpacity: 0.18, stroke: color, strokeWidth: sw,
    strokeLinejoin: 'round', strokeLinecap: 'round' };

  switch (name) {
    case 'trend':
      return <svg {...props}><path d="M3 17l6-6 4 4 8-8" {...fillSoft} fill="none"/><path d="M14 7h7v7" /></svg>;
    case 'shield':
      return <svg {...props}><path d="M12 3l8 3v6c0 4.5-3.5 8.5-8 9-4.5-.5-8-4.5-8-9V6z" {...fillSoft}/><path d="M9 12.5l2 2 4.5-4.5"/></svg>;
    case 'spark':
      return <svg {...props}><path d="M12 3l1.7 5.3L19 10l-5.3 1.7L12 17l-1.7-5.3L5 10l5.3-1.7z" {...fillSoft}/></svg>;
    case 'target':
      return <svg {...props}><circle cx="12" cy="12" r="9" {...fillSoft}/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill={color} stroke="none"/></svg>;
    case 'flame':
      return <svg {...props}><path d="M12 3c0 4-4.5 5.5-4.5 11A4.5 4.5 0 0 0 12 18.5a4.5 4.5 0 0 0 4.5-4.5c0-2.7-1.7-3.5-1.7-6.5 0 1.7-2.8 1.7-2.8-4.5z" {...fillSoft}/></svg>;
    case 'wave':
      return <svg {...props}><path d="M3 12h2M7 8v8M11 4v16M15 7v10M19 10v4M21 12h-1" /></svg>;
    case 'trophy':
      return <svg {...props}><path d="M7 4h10v5a5 5 0 0 1-10 0z" {...fillSoft}/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/><path d="M9 17h6l-1 3h-4z"/><path d="M10 14h4"/></svg>;
    case 'lock':
      return <svg {...props}><rect x="5" y="11" width="14" height="9" rx="2.5" {...fillSoft}/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>;
    case 'arrow':
      return <svg {...props}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case 'chevron':
      return <svg {...props}><path d="M9 6l6 6-6 6"/></svg>;
    case 'check':
      return <svg {...props}><circle cx="12" cy="12" r="9" fill={color} stroke="none"/><path d="M8 12.5l3 3 5-6.5" stroke="#fff"/></svg>;
    case 'mic':
      return <svg {...props}><rect x="9" y="3" width="6" height="11" rx="3" {...fillSoft}/><path d="M5 12a7 7 0 0 0 14 0M12 19v3M8 22h8"/></svg>;
    case 'pause':
      return <svg {...props}><rect x="6" y="5" width="3.5" height="14" rx="1.5" fill={color} stroke="none"/><rect x="14.5" y="5" width="3.5" height="14" rx="1.5" fill={color} stroke="none"/></svg>;
    case 'clock':
      return <svg {...props}><circle cx="12" cy="12" r="9" {...fillSoft}/><path d="M12 7v5l3.5 2"/></svg>;
    case 'pressure':
      return <svg {...props}><circle cx="12" cy="13" r="8" {...fillSoft}/><path d="M12 13l4-4M9 4h6"/></svg>;
    case 'route':
      return <svg {...props}><circle cx="6" cy="19" r="2.5" {...fillSoft}/><circle cx="18" cy="5" r="2.5" {...fillSoft}/><path d="M8.5 19H17a4 4 0 0 0 0-8H7a4 4 0 0 1 0-8h8.5"/></svg>;
    case 'people':
      return <svg {...props}><circle cx="9" cy="9" r="3.5" {...fillSoft}/><circle cx="17" cy="11" r="2.7" {...fillSoft}/><path d="M2 20c0-3.5 3-5.5 7-5.5s7 2 7 5.5"/><path d="M16 20c0-2.3 1.7-3.7 4-3.7"/></svg>;
    default: return null;
  }
};

// ───────────────── pressable ─────────────────
const Pressable = ({ children, onClick, onLongPress, style = {}, ...rest }) => {
  const [pressed, setPressed] = useState(false);
  const lpTimer = useRef(null);
  const lpFired = useRef(false);
  const start = () => {
    setPressed(true); lpFired.current = false;
    if (onLongPress) lpTimer.current = setTimeout(() => { lpFired.current = true; onLongPress(); }, 500);
  };
  const end = () => {
    setPressed(false);
    if (lpTimer.current) { clearTimeout(lpTimer.current); lpTimer.current = null; }
  };
  return (
    <div {...rest}
      onMouseDown={start} onMouseUp={end} onMouseLeave={end}
      onTouchStart={start} onTouchEnd={end}
      onClick={() => { if (!lpFired.current) onClick && onClick(); }}
      style={{
        cursor: 'pointer',
        transition: 'transform 260ms cubic-bezier(0.2,1,0.3,1), opacity 260ms',
        transform: pressed ? 'scale(0.97)' : 'scale(1)',
        opacity: pressed ? 0.85 : 1,
        ...style,
      }}>
      {children}
    </div>
  );
};

// ───────────────── card ─────────────────
const Card = ({ children, padding = 18, style = {} }) => (
  <div style={{
    background: '#fff',
    borderRadius: 22,
    padding,
    border: '1px solid rgba(15,23,42,0.04)',
    boxShadow: '0 1px 0 rgba(15,23,42,0.03), 0 8px 22px -12px rgba(15,23,42,0.14)',
    ...style,
  }}>{children}</div>
);

const MicroLabel = ({ children, style }) => (
  <div style={{
    fontFamily: "'Manrope', system-ui", fontSize: 11, fontWeight: 700,
    letterSpacing: 1.1, textTransform: 'uppercase', color: TINT.slate,
    margin: '20px 0 10px',
    ...style,
  }}>{children}</div>
);

// ───────────────── DATA (representative coaching data) ─────────────────
const WEEKS = [
  { label: 'This week', score: 78, deltaPct: +12, fillerRate: 2.4, fillerDelta: -22,
    pressure: 71, pressureDelta: +6, streak: 12,
    fillerSpark: [4.6, 3.9, 3.4, 3.1, 2.8, 2.6, 2.4],
    activityDots: [2, 1, 0, 3, 1, 2, 4], // sessions per day, last 7
  },
  { label: 'Last week', score: 70, deltaPct: +4, fillerRate: 3.1, fillerDelta: -8,
    pressure: 67, pressureDelta: +2, streak: 5,
    fillerSpark: [4.9, 4.4, 4.0, 3.7, 3.4, 3.2, 3.1],
    activityDots: [1, 2, 1, 0, 2, 1, 3],
  },
];

const STRONGEST = {
  trait: 'Steady cadence',
  detail: 'Your pace stays within 140–160 WPM even when prompts get harder. That\'s top-decile for this product.',
  evidence: '6 of 7 sessions held cadence within target band.',
};

const BLOCKER = {
  trait: 'Opens with filler',
  detail: 'You start 64% of answers with "so" or "um" before the first noun. Once you\'re past sentence one, fillers drop sharply.',
  evidence: 'First-sentence filler rate: 64%. After that: 9%.',
};

const ACHIEVEMENTS = [
  { id:'a1', title: 'First clean rep',     sub: 'Zero fillers in 60s', earned:true,  date:'Apr 28', glyph:'check',   tint:TINT.green },
  { id:'a2', title: '7-day streak',        sub: 'A week of practice', earned:true,  date:'May 1',  glyph:'flame',   tint:TINT.orange },
  { id:'a3', title: 'Pressure proof',      sub: 'Sudden Death survivor', earned:true, date:'May 2', glyph:'shield',  tint:TINT.indigo },
  { id:'a4', title: 'Cadence keeper',     sub: 'Hold WPM 4 sessions', earned:false, glyph:'wave',    tint:TINT.blue },
  { id:'a5', title: 'Filler under one',   sub: 'Avg <1 per minute',   earned:false, glyph:'spark',   tint:TINT.purple },
];

const NEXT_FOCUS = {
  title: 'Tighten your opens',
  why: 'Fillers cluster in your first sentence. Three Sudden Death reps will train cleaner starts.',
  cta: 'Start 3-rep set',
  mode: 'Sudden Death',
  tint: TINT.orange,
  glyph: 'pressure',
};

// ───────────────── PIECES ─────────────────

// Headline card: weekly score, swipeable between weeks
const HeadlineCard = ({ weekIdx, setWeekIdx }) => {
  const w = WEEKS[weekIdx];
  const score = useCountUp(w.score, { duration: 1000, trigger: true });
  // re-mount on week change for fresh count-up
  return (
    <div key={weekIdx} style={{ position: 'relative' }}>
      <Card padding={22} style={{ overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Pressable
            onClick={() => setWeekIdx(Math.min(WEEKS.length - 1, weekIdx + 1))}
            style={{ display:'flex', alignItems:'center', gap:6, color: weekIdx === WEEKS.length - 1 ? '#cdd2db' : TINT.slate, fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:12 }}
          >
            <span style={{ transform:'scaleX(-1)', display:'inline-block' }}><Glyph name="chevron" size={14}/></span>
            <span style={{ letterSpacing:0.4, textTransform:'uppercase' }}>Prev</span>
          </Pressable>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:12, color: TINT.slate, letterSpacing:0.6, textTransform:'uppercase' }}>{w.label}</div>
          <Pressable
            onClick={() => setWeekIdx(Math.max(0, weekIdx - 1))}
            style={{ display:'flex', alignItems:'center', gap:6, color: weekIdx === 0 ? '#cdd2db' : TINT.slate, fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:12 }}
          >
            <span style={{ letterSpacing:0.4, textTransform:'uppercase' }}>Next</span>
            <Glyph name="chevron" size={14}/>
          </Pressable>
        </div>

        <div style={{ display:'flex', alignItems:'flex-end', gap:10, marginTop: 18 }}>
          <div style={{
            fontFamily:"'Figtree',system-ui",
            fontWeight:800, fontSize:84, lineHeight:0.9, letterSpacing:'-0.04em',
            color: TINT.blue,
          }}>{score}</div>
          <div style={{
            fontFamily:"'Figtree',system-ui",
            fontWeight:700, fontSize:22, color: TINT.slate, paddingBottom:10,
          }}>/100</div>
        </div>
        <div style={{
          fontFamily:"'Manrope',system-ui",
          fontWeight:600, fontSize:14, color: TINT.slate, marginTop: 4,
        }}>Communication score</div>

        <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:14 }}>
          <DeltaPill value={w.deltaPct} suffix="% vs last week"/>
        </div>

        {/* week activity dots */}
        <div style={{ display:'flex', justifyContent:'space-between', marginTop:18 }}>
          {w.activityDots.map((n, i) => (
            <ActivityDay key={i} count={n} dayIdx={i}/>
          ))}
        </div>
      </Card>
    </div>
  );
};

const ActivityDay = ({ count, dayIdx }) => {
  const dayName = ['M','T','W','T','F','S','S'][dayIdx];
  const intensity = Math.min(count / 4, 1);
  const isToday = dayIdx === 6;
  return (
    <div style={{ display:'flex', flexDirection:'column', alignItems:'center', gap:6 }}>
      <div style={{
        width: 22, height: 22, borderRadius: 7,
        background: count === 0 ? 'rgba(15,23,42,.05)' : `rgba(51,120,245, ${0.15 + intensity * 0.7})`,
        border: isToday ? `1.5px solid ${TINT.blue}` : '1.5px solid transparent',
        boxSizing: 'border-box',
      }}/>
      <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:10, color: TINT.slate, letterSpacing:0.4 }}>{dayName}</div>
    </div>
  );
};

const DeltaPill = ({ value, suffix = '' }) => {
  const pos = value >= 0;
  const color = pos ? TINT.green : TINT.red;
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap:5,
      padding:'5px 10px', borderRadius:999,
      background: `${color}14`,
      color, fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:12,
    }}>
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" style={{ transform: pos ? 'none' : 'scaleY(-1)' }}>
        <path d="M5 14l7-7 7 7"/>
      </svg>
      <span>{pos ? '+' : ''}{value}{suffix}</span>
    </div>
  );
};

// Insight pair card — "what's working" / "where it breaks"
const InsightCard = ({ kind, glyph, tint, label, headline, sub, evidence, expanded, onToggle }) => (
  <Pressable onClick={onToggle} style={{ display:'block' }}>
    <Card padding={16}>
      <div style={{ display:'flex', alignItems:'center', gap:12 }}>
        <IconTile tint={tint}><Glyph name={glyph} size={18} color={tint}/></IconTile>
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: TINT.slate, letterSpacing:0.8, textTransform:'uppercase' }}>{label}</div>
          <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:700, fontSize:18, color:'#212633', letterSpacing:'-0.005em', marginTop:1 }}>{headline}</div>
        </div>
        <div style={{
          color: TINT.slate,
          transition:'transform 320ms cubic-bezier(0.2,1,0.3,1)',
          transform: expanded ? 'rotate(90deg)' : 'rotate(0deg)',
        }}>
          <Glyph name="chevron" size={16} color={TINT.slate}/>
        </div>
      </div>
      <ExpandRegion open={expanded}>
        <div style={{ marginTop:14, paddingTop:14, borderTop:'1px solid rgba(15,23,42,.05)' }}>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13.5, lineHeight:1.45, color:'#3a4253' }}>{sub}</div>
          <div style={{ marginTop:10, display:'flex', alignItems:'center', gap:8 }}>
            <span style={{ width:6, height:6, borderRadius:'50%', background: tint }}/>
            <span style={{ fontFamily:"'Manrope',system-ui", fontWeight:600, fontSize:12, color: tint }}>{evidence}</span>
          </div>
        </div>
      </ExpandRegion>
    </Card>
  </Pressable>
);

// Expandable region using grid-template-rows trick → animates intrinsic height
const ExpandRegion = ({ open, children }) => (
  <div style={{
    display:'grid',
    gridTemplateRows: open ? '1fr' : '0fr',
    transition:'grid-template-rows 320ms cubic-bezier(0.2,1,0.3,1), opacity 240ms',
    opacity: open ? 1 : 0,
  }}>
    <div style={{ overflow:'hidden' }}>{children}</div>
  </div>
);

// Filler trend card — sparkline + inline detail
const FillerTrendCard = ({ data, current, delta, expanded, onToggle }) => {
  const w = 280, h = 60, pad = 4;
  const min = Math.min(...data) - 0.4, max = Math.max(...data) + 0.4;
  const xs = data.map((_, i) => pad + (i * (w - 2*pad)) / (data.length - 1));
  const ys = data.map(v => h - pad - ((v - min) / (max - min)) * (h - 2*pad));
  const linePath = data.map((_, i) => `${i === 0 ? 'M' : 'L'} ${xs[i].toFixed(1)} ${ys[i].toFixed(1)}`).join(' ');
  const areaPath = `${linePath} L ${xs[xs.length-1].toFixed(1)} ${h-pad} L ${xs[0].toFixed(1)} ${h-pad} Z`;
  const [drawn, setDrawn] = useState(false);
  useEffect(() => { const t = setTimeout(() => setDrawn(true), 80); return () => clearTimeout(t); }, []);
  const lineRef = useRef(null);
  const [pathLen, setPathLen] = useState(0);
  useEffect(() => { if (lineRef.current) setPathLen(lineRef.current.getTotalLength()); }, []);

  const value = useCountUp(current, { decimals: 1, duration: 1000 });

  return (
    <Pressable onClick={onToggle} style={{ display:'block' }}>
      <Card padding={18}>
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <IconTile tint={TINT.green}><Glyph name="trend" size={18} color={TINT.green}/></IconTile>
          <div style={{ flex:1 }}>
            <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: TINT.slate, letterSpacing:0.8, textTransform:'uppercase' }}>Filler trend</div>
            <div style={{ display:'flex', alignItems:'baseline', gap:8, marginTop:2 }}>
              <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:28, color:'#212633', letterSpacing:'-0.01em', lineHeight:1 }}>{value}</div>
              <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:600, fontSize:12, color: TINT.slate }}>per minute</div>
            </div>
          </div>
          <DeltaPill value={delta} suffix="%"/>
        </div>

        <svg width="100%" height={h + 8} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ marginTop: 10, display:'block' }}>
          <defs>
            <linearGradient id="trendArea" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor={TINT.green} stopOpacity="0.22"/>
              <stop offset="1" stopColor={TINT.green} stopOpacity="0"/>
            </linearGradient>
          </defs>
          <path d={areaPath} fill="url(#trendArea)" style={{ opacity: drawn ? 1 : 0, transition: 'opacity 700ms 200ms' }}/>
          <path ref={lineRef} d={linePath} fill="none" stroke={TINT.green} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"
            style={{
              strokeDasharray: pathLen, strokeDashoffset: drawn ? 0 : pathLen,
              transition:'stroke-dashoffset 900ms cubic-bezier(0.2,1,0.3,1)',
            }}/>
          {xs.map((x, i) => (
            <circle key={i} cx={x} cy={ys[i]} r={i === xs.length - 1 ? 3.5 : 0} fill="#fff" stroke={TINT.green} strokeWidth="2.2"
              style={{ opacity: drawn ? 1 : 0, transition: 'opacity 300ms 900ms' }}/>
          ))}
        </svg>

        <ExpandRegion open={expanded}>
          <div style={{ marginTop:12, paddingTop:12, borderTop:'1px solid rgba(15,23,42,.05)', display:'grid', gridTemplateColumns:'1fr 1fr', gap:10 }}>
            <Mini label="Sessions" value="14" />
            <Mini label="Cleanest rep" value="0.6/min" />
            <Mini label="Most common" value='"so"' />
            <Mini label="Best streak" value="3 reps" />
          </div>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13, lineHeight:1.45, color:'#3a4253', marginTop: 12 }}>
            Your filler-word rate dropped almost in half this week. Most of the remaining fillers happen in the first second of speaking.
          </div>
        </ExpandRegion>
      </Card>
    </Pressable>
  );
};

const Mini = ({ label, value }) => (
  <div>
    <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:10, color: TINT.slate, letterSpacing:0.6, textTransform:'uppercase' }}>{label}</div>
    <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:700, fontSize:16, color:'#212633', marginTop:2 }}>{value}</div>
  </div>
);

// Pressure stability — animated radial ring
const PressureCard = ({ pct, delta, expanded, onToggle }) => {
  const animated = useCountUp(pct, { duration: 900 });
  const r = 28, c = 2 * Math.PI * r;
  const offset = c - (animated / 100) * c;
  return (
    <Pressable onClick={onToggle} style={{ display:'block', flex:1 }}>
      <Card padding={16}>
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <div style={{ position:'relative', width:64, height:64, flexShrink:0 }}>
            <svg width="64" height="64" viewBox="0 0 64 64" style={{ transform:'rotate(-90deg)' }}>
              <circle cx="32" cy="32" r={r} fill="none" stroke={`${TINT.indigo}1f`} strokeWidth="6"/>
              <circle cx="32" cy="32" r={r} fill="none" stroke={TINT.indigo} strokeWidth="6"
                strokeLinecap="round" strokeDasharray={c} strokeDashoffset={offset}
                style={{ transition: 'stroke-dashoffset 900ms cubic-bezier(0.2,1,0.3,1)' }}/>
            </svg>
            <div style={{ position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:18, color: TINT.indigo, letterSpacing:'-0.01em' }}>
              {animated}
            </div>
          </div>
          <div style={{ minWidth:0, flex:1 }}>
            <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: TINT.slate, letterSpacing:0.8, textTransform:'uppercase' }}>Pressure stability</div>
            <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:700, fontSize:16, color:'#212633', marginTop:2, lineHeight:1.2 }}>Holds under load</div>
            <div style={{ marginTop:6 }}><DeltaPill value={delta} suffix=" pts"/></div>
          </div>
        </div>
        <ExpandRegion open={expanded}>
          <div style={{ marginTop:12, paddingTop:12, borderTop:'1px solid rgba(15,23,42,.05)', fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13, lineHeight:1.45, color:'#3a4253' }}>
            Score retention from low-pressure to Sudden Death prompts. You lose only 12 points under pressure — top quartile for active users.
          </div>
        </ExpandRegion>
      </Card>
    </Pressable>
  );
};

// Streak card — quiet, calendar dots
const StreakCard = ({ days, expanded, onToggle }) => {
  const animated = useCountUp(days, { duration: 900 });
  return (
    <Pressable onClick={onToggle} style={{ display:'block', flex:1 }}>
      <Card padding={16}>
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <IconTile tint={TINT.orange} size={48} radius={14}><Glyph name="flame" size={22} color={TINT.orange}/></IconTile>
          <div style={{ minWidth:0, flex:1 }}>
            <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: TINT.slate, letterSpacing:0.8, textTransform:'uppercase' }}>Streak</div>
            <div style={{ display:'flex', alignItems:'baseline', gap:6, marginTop:2 }}>
              <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:28, color:'#212633', letterSpacing:'-0.01em', lineHeight:1 }}>{animated}</div>
              <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:600, fontSize:12, color: TINT.slate }}>days</div>
            </div>
          </div>
        </div>
        <div style={{ display:'grid', gridTemplateColumns:'repeat(14, 1fr)', gap:4, marginTop:14 }}>
          {Array.from({ length: 14 }).map((_, i) => {
            const filled = i >= 14 - days;
            return <div key={i} style={{
              aspectRatio:'1', borderRadius: 4,
              background: filled ? TINT.orange : 'rgba(15,23,42,.06)',
              opacity: filled ? (0.55 + (i / 14) * 0.45) : 1,
            }}/>;
          })}
        </div>
        <ExpandRegion open={expanded}>
          <div style={{ marginTop:12, paddingTop:12, borderTop:'1px solid rgba(15,23,42,.05)', fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13, lineHeight:1.45, color:'#3a4253' }}>
            Last 14 days. One rep counts as practiced. Don't break the chain — your improvements compound after day 21.
          </div>
        </ExpandRegion>
      </Card>
    </Pressable>
  );
};

// Achievements rail
const AchievementsRail = ({ items, onPick }) => (
  <div style={{
    display:'flex', gap:10, overflowX:'auto', padding:'2px 20px 8px', margin:'0 -20px',
    scrollbarWidth:'none',
  }}>
    <style>{`.ach-rail::-webkit-scrollbar{display:none}`}</style>
    {items.map(a => (
      <Pressable key={a.id} onClick={() => onPick(a)} style={{ flexShrink:0 }}>
        <div style={{
          width: 132, padding: 14, borderRadius: 18,
          background: '#fff',
          border: '1px solid rgba(15,23,42,0.04)',
          boxShadow: '0 1px 0 rgba(15,23,42,0.03), 0 8px 22px -12px rgba(15,23,42,0.14)',
          opacity: a.earned ? 1 : 0.55,
          filter: a.earned ? 'none' : 'saturate(0.4)',
        }}>
          <IconTile tint={a.tint} size={40} radius={13}>
            <Glyph name={a.earned ? a.glyph : 'lock'} size={20} color={a.tint}/>
          </IconTile>
          <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:700, fontSize:14, color:'#212633', marginTop:10, letterSpacing:'-0.005em', lineHeight:1.2 }}>{a.title}</div>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:11.5, color: TINT.slate, marginTop:3, lineHeight:1.3 }}>{a.sub}</div>
          {a.earned && (
            <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:10.5, color: a.tint, marginTop:8, letterSpacing:0.4 }}>Earned · {a.date}</div>
          )}
        </div>
      </Pressable>
    ))}
  </div>
);

// Next focus — single CTA
const NextFocusCard = ({ data }) => (
  <Card padding={20} style={{ background: `linear-gradient(180deg, ${data.tint}0d 0%, #fff 60%)` }}>
    <div style={{ display:'flex', alignItems:'flex-start', gap:14 }}>
      <IconTile tint={data.tint} size={44} radius={14}><Glyph name={data.glyph} size={22} color={data.tint}/></IconTile>
      <div style={{ flex:1 }}>
        <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: data.tint, letterSpacing:0.8, textTransform:'uppercase' }}>Next focus</div>
        <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:20, color:'#212633', marginTop:2, letterSpacing:'-0.01em' }}>{data.title}</div>
        <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13.5, color:'#3a4253', marginTop:6, lineHeight:1.45 }}>{data.why}</div>
      </div>
    </div>
    <Pressable style={{
      display:'flex', alignItems:'center', justifyContent:'center', gap:8, marginTop: 16,
      padding:'13px 18px', borderRadius: 999,
      background: `linear-gradient(180deg, ${lighten(data.tint)} 0%, ${data.tint} 100%)`,
      color:'#fff', fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:15, letterSpacing:'-0.005em',
    }}>
      <span>{data.cta}</span>
      <Glyph name="arrow" size={16} color="#fff"/>
    </Pressable>
  </Card>
);

function lighten(hex) {
  const map = { '#3378F5':'#5E9BFF', '#F28C26':'#FFB066', '#249970':'#4FC49A', '#526EF0':'#7D92F5', '#8F47EB':'#BF87FA', '#D4851A':'#F2B25C', '#BD3833':'#E36459' };
  return map[hex] || hex;
}

// Achievement detail sheet
const AchievementSheet = ({ achievement, onClose }) => {
  if (!achievement) return null;
  return (
    <div onClick={onClose} style={{
      position:'absolute', inset:0, background:'rgba(15,23,42,.32)', zIndex: 30,
      display:'flex', alignItems:'flex-end',
      animation:'noum-fade-in 240ms cubic-bezier(0.2,1,0.3,1)',
    }}>
      <div onClick={e => e.stopPropagation()} style={{
        background:'#fff', width:'100%', borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: 24, paddingBottom: 32,
        animation:'noum-sheet-up 360ms cubic-bezier(0.2,1,0.3,1)',
      }}>
        <div style={{ width:40, height:4, borderRadius:999, background:'rgba(15,23,42,.12)', margin:'0 auto 18px' }}/>
        <div style={{ display:'flex', alignItems:'center', gap:14 }}>
          <IconTile tint={achievement.tint} size={56} radius={18}>
            <Glyph name={achievement.earned ? achievement.glyph : 'lock'} size={28} color={achievement.tint}/>
          </IconTile>
          <div>
            <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:22, color:'#212633', letterSpacing:'-0.01em' }}>{achievement.title}</div>
            <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:14, color: TINT.slate, marginTop:3 }}>{achievement.sub}</div>
          </div>
        </div>
        <div style={{ marginTop: 18, padding: 14, borderRadius: 14, background: `${achievement.tint}0d` }}>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: achievement.tint, letterSpacing:0.8, textTransform:'uppercase' }}>
            {achievement.earned ? 'Earned' : 'Locked'}
          </div>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:500, fontSize:13.5, color:'#3a4253', marginTop:4, lineHeight:1.45 }}>
            {achievement.earned
              ? `Awarded on ${achievement.date}. Keep practicing to compound the win.`
              : `Keep going. ${achievement.sub} unlocks this badge.`}
          </div>
        </div>
        <Pressable onClick={onClose} style={{
          marginTop: 16, padding:'13px 18px', borderRadius: 999,
          background: '#F2F3F7', color: '#212633',
          fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:15,
          textAlign:'center',
        }}>Close</Pressable>
      </div>
    </div>
  );
};

// ───────────────── SCREEN ─────────────────
function CommunicationProfileScreen() {
  const [weekIdx, setWeekIdx] = useState(0);
  const [open, setOpen] = useState(null); // 'working' | 'breaks' | 'filler' | 'pressure' | 'streak'
  const [sheet, setSheet] = useState(null);

  // swipe gesture on the whole scroll surface (touch only)
  const touchStart = useRef(null);
  const onTouchStart = e => { touchStart.current = e.touches[0].clientX; };
  const onTouchEnd = e => {
    if (touchStart.current == null) return;
    const dx = e.changedTouches[0].clientX - touchStart.current;
    if (Math.abs(dx) > 60) {
      if (dx < 0) setWeekIdx(i => Math.min(WEEKS.length - 1, i + 1));
      else        setWeekIdx(i => Math.max(0, i - 1));
    }
    touchStart.current = null;
  };

  const w = WEEKS[weekIdx];
  const toggle = (key) => setOpen(open === key ? null : key);

  return (
    <div style={{ position:'absolute', inset:0, background:'#F4F4F8', overflowY:'auto', overflowX:'hidden' }}
      onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>

      <style>{`
        @keyframes noum-fade-in { from { opacity: 0; } to { opacity: 1; } }
        @keyframes noum-sheet-up { from { transform: translateY(100%); } to { transform: translateY(0); } }
      `}</style>

      {/* Top app bar */}
      <div style={{ paddingTop: 56, paddingLeft: 20, paddingRight: 20, display:'flex', justifyContent:'space-between', alignItems:'center' }}>
        <div>
          <div style={{ fontFamily:"'Manrope',system-ui", fontWeight:700, fontSize:11, color: TINT.slate, letterSpacing:1.2, textTransform:'uppercase' }}>Profile</div>
          <div style={{ fontFamily:"'Figtree',system-ui", fontWeight:800, fontSize:28, color:'#212633', letterSpacing:'-0.02em', marginTop:2 }}>Jordan Chen</div>
        </div>
        <Pressable style={{
          width:40, height:40, borderRadius:20, background:'#fff',
          display:'flex', alignItems:'center', justifyContent:'center',
          border:'1px solid rgba(15,23,42,.05)',
          boxShadow:'0 1px 0 rgba(15,23,42,.03), 0 8px 22px -12px rgba(15,23,42,.14)',
        }}>
          <Glyph name="route" size={18} color={TINT.slate}/>
        </Pressable>
      </div>

      <div style={{ padding:'18px 20px 110px', display:'flex', flexDirection:'column', gap:10 }}>
        <HeadlineCard weekIdx={weekIdx} setWeekIdx={setWeekIdx}/>

        <MicroLabel>What's working</MicroLabel>
        <InsightCard
          kind="working" glyph="spark" tint={TINT.green}
          label="Strongest trait" headline={STRONGEST.trait}
          sub={STRONGEST.detail} evidence={STRONGEST.evidence}
          expanded={open === 'working'} onToggle={() => toggle('working')}
        />

        <MicroLabel>Where it breaks</MicroLabel>
        <InsightCard
          kind="breaks" glyph="target" tint={TINT.amber}
          label="Recurring blocker" headline={BLOCKER.trait}
          sub={BLOCKER.detail} evidence={BLOCKER.evidence}
          expanded={open === 'breaks'} onToggle={() => toggle('breaks')}
        />

        <MicroLabel>Trends</MicroLabel>
        <FillerTrendCard
          data={w.fillerSpark} current={w.fillerRate} delta={w.fillerDelta}
          expanded={open === 'filler'} onToggle={() => toggle('filler')}
        />
        <div style={{ display:'flex', gap:10 }}>
          <PressureCard pct={w.pressure} delta={w.pressureDelta} expanded={open === 'pressure'} onToggle={() => toggle('pressure')}/>
        </div>
        <StreakCard days={w.streak} expanded={open === 'streak'} onToggle={() => toggle('streak')}/>

        <MicroLabel>Recent wins</MicroLabel>
        <AchievementsRail items={ACHIEVEMENTS} onPick={setSheet}/>

        <div style={{ height: 6 }}/>
        <NextFocusCard data={NEXT_FOCUS}/>
      </div>

      <AchievementSheet achievement={sheet} onClose={() => setSheet(null)}/>
    </div>
  );
}

window.CommunicationProfileScreen = CommunicationProfileScreen;
