// Noum UI kit · shared primitives
// Lifted from Noum/DesignSystem.swift + GamifiedViews.swift

const { useState, useEffect, useRef } = React;

// Lucide-style inline icons (SF Symbol substitutes) — stroke 2.25 for .bold
const Icon = ({ name, size = 18, color = 'currentColor', fill = 'none', strokeWidth = 2.25 }) => {
  const p = {
    timer: <g><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></g>,
    bolt: <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>,
    waveform: <path d="M2 12h2l2-7 4 14 4-10 2 5h6"/>,
    message: <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>,
    dumbbell: <g><path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/><rect x="1" y="9" width="5" height="6" rx="1"/><rect x="18" y="9" width="5" height="6" rx="1"/><rect x="5" y="7" width="4" height="10" rx="1"/><rect x="15" y="7" width="4" height="10" rx="1"/></g>,
    book: <path d="M4 3h10a4 4 0 0 1 4 4v14a2 2 0 0 0-2-2H4zM4 3v16M4 19h14"/>,
    users: <g><circle cx="9" cy="8" r="4"/><path d="M2 21c1-4 4-6 7-6s6 2 7 6"/><circle cx="17" cy="10" r="3"/><path d="M15 20c.5-3 2.5-4 5-4"/></g>,
    sliders: <g><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/><circle cx="9" cy="6" r="2" fill={color}/><circle cx="15" cy="12" r="2" fill={color}/><circle cx="11" cy="18" r="2" fill={color}/></g>,
    sparkles: <g><path d="M12 3l1.5 5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1L12 3z"/><path d="M19 15l.8 2.5L22 18l-2.2.5L19 21l-.8-2.5L16 18l2.2-.5z"/></g>,
    star: <polygon points="12 2 14 9 22 9.5 16 14.5 18 22 12 17.5 6 22 8 14.5 2 9.5 10 9"/>,
    check: <g><circle cx="12" cy="12" r="10" fill={color} stroke="none"/><path d="M7.5 12.5l3 3 6-7" stroke="#fff" fill="none" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></g>,
    circle: <circle cx="12" cy="12" r="10"/>,
    chevron: <polyline points="9 18 15 12 9 6"/>,
    mic: <g><rect x="9" y="3" width="6" height="11" rx="3" fill={color} stroke="none"/><path d="M5 12a7 7 0 0 0 14 0M12 19v3M8 22h8"/></g>,
    mic_open: <g><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 12a7 7 0 0 0 14 0M12 19v3M8 22h8"/></g>,
    arrow_right: <g><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></g>,
    pause: <g><rect x="6" y="5" width="4" height="14" rx="1" fill={color} stroke="none"/><rect x="14" y="5" width="4" height="14" rx="1" fill={color} stroke="none"/></g>,
    x: <g><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></g>,
    crown: <path d="M2 18l3-10 5 5 2-8 2 8 5-5 3 10z"/>,
    shield: <path d="M12 2l9 4v6c0 5-4 9-9 10-5-1-9-5-9-10V6z"/>,
    apple: <path d="M16.4 12.5c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.9-1.5-.1-2.8.8-3.6.8-.8 0-1.9-.8-3.1-.8C7 7.2 4.8 8.5 3.7 10.6c-1.6 2.8-.4 6.9 1.1 9.1.7 1.1 1.6 2.3 2.8 2.3 1.1 0 1.5-.7 2.9-.7 1.3 0 1.7.7 2.9.7 1.2 0 2-1.1 2.7-2.2.9-1.3 1.3-2.5 1.3-2.6-.1 0-2.5-.9-2.5-3.7zM14 5.3c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.6.6-1.1 1.6-.9 2.6 1 .1 2-.5 2.5-1.2z"/>,
    google: <g stroke="none"><path d="M21.35 11.1H12v2.8h5.4c-.5 2.3-2.5 3.4-5.4 3.4-3.2 0-5.8-2.6-5.8-5.8s2.6-5.8 5.8-5.8c1.5 0 2.8.5 3.8 1.4l2.1-2.1C16.1 3.4 14.2 2.5 12 2.5 6.5 2.5 2 7 2 12.5S6.5 22.5 12 22.5c5.8 0 9.6-4 9.6-9.7 0-.6-.1-1.1-.25-1.7z" fill={color}/></g>,
    flame: <path d="M12 2c0 5-5 6-5 12a5 5 0 0 0 10 0c0-3-2-4-2-7 0 2-3 2-3-5z"/>,
    route: <g><circle cx="6" cy="19" r="3"/><circle cx="18" cy="5" r="3"/><path d="M9 19h8a4 4 0 0 0 0-8H7a4 4 0 0 1 0-8h8"/></g>,
    trophy: <g><path d="M7 4h10v4a5 5 0 0 1-10 0z"/><path d="M17 4h3v2a3 3 0 0 1-3 3M7 4H4v2a3 3 0 0 0 3 3"/><path d="M9 16h6l-1 4h-4z"/></g>,
    settings_gear: <g><circle cx="12" cy="12" r="3"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></g>,
    target: <g><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill={color} stroke="none"/></g>,
    bubble_two: <g><path d="M3 8a3 3 0 0 1 3-3h7a3 3 0 0 1 3 3v3a3 3 0 0 1-3 3H8l-3 3V8z" fill={color} stroke="none" opacity="0.6"/><path d="M10 13a3 3 0 0 1 3-3h5a3 3 0 0 1 3 3v3a3 3 0 0 1-3 3h-2l-3 3v-3" fill={color} stroke="none"/></g>,
    trending_up: <g><polyline points="3 17 9 11 13 15 21 7"/><polyline points="15 7 21 7 21 13"/></g>,
    mic_clean: <g><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 12a7 7 0 0 0 14 0M12 19v3M8 22h8"/></g>,
  }[name] || null;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color}
      strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round"
      style={{display:'inline-block',verticalAlign:'middle',flexShrink:0}}>
      {p}
    </svg>
  );
};

// Card container — white, 24/28 corner, soft shadow, 1pt white border
const Card = ({ children, xl = false, style = {}, tintShadow, ...rest }) => (
  <div {...rest} style={{
    background: '#fff',
    borderRadius: xl ? 28 : 24,
    padding: 20,
    border: '1px solid rgba(255,255,255,0.72)',
    boxShadow: tintShadow
      ? `0 8px 16px ${tintShadow}1a`
      : '0 8px 24px rgba(33,38,51,0.06)',
    ...style,
  }}>{children}</div>
);

// Pressable wrapper — 0.97 scale + 0.85 opacity on active
const Pressable = ({ children, onClick, style = {}, ...rest }) => {
  const [pressed, setPressed] = useState(false);
  return (
    <div {...rest}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onTouchStart={() => setPressed(true)}
      onTouchEnd={() => setPressed(false)}
      onClick={onClick}
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

// ShimmerProgressBar — 2.4s shimmer sweep
const ShimmerBar = ({ progress = 0.5, tint = '#3378F5', height = 12 }) => {
  const w = Math.max(progress * 100, 3);
  return (
    <div style={{height, borderRadius: 999, background:'rgba(0,0,0,0.08)', position:'relative', overflow:'hidden'}}>
      <div style={{
        position:'absolute', left:0, top:0, bottom:0, width: `${w}%`,
        borderRadius: 999,
        background: `linear-gradient(90deg, ${tint}d9, ${tint}, ${tint}b8)`,
      }}>
        <div style={{
          position:'absolute', top:0, bottom:0, width: 26,
          background:'rgba(255,255,255,0.35)', filter:'blur(4px)',
          animation: 'noum-shimmer 2.4s linear infinite',
        }}/>
      </div>
    </div>
  );
};

// PulseBadge — breathing ring
const PulseBadge = ({ name, tint = '#3378F5', size = 56 }) => (
  <div style={{width:size, height:size, position:'relative', display:'inline-flex',alignItems:'center',justifyContent:'center', flexShrink:0}}>
    <div style={{position:'absolute', inset:0, borderRadius:'50%', border:`1.5px solid ${tint}38`, animation:'noum-pulse-ring 1.8s ease-in-out infinite'}}/>
    <div style={{position:'absolute', inset:4, borderRadius:'50%', background:`${tint}1f`, animation:'noum-pulse-fill 1.8s ease-in-out infinite'}}/>
    <Icon name={name} size={Math.round(size*0.42)} color={tint} fill={tint} strokeWidth={1.5}/>
  </div>
);

const SparkleRibbon = ({ tint = '#D4851A' }) => (
  <div style={{display:'inline-flex', gap:6, alignItems:'center'}}>
    {[0,1,2,3,4].map(i => (
      <span key={i} style={{
        color: tint,
        fontSize: i%2===0 ? 11 : 9,
        opacity: 0.75,
        animation: `noum-twinkle 1.6s ease-in-out ${i*0.12}s infinite`,
      }}>{i%2===0 ? '✦' : '★'}</span>
    ))}
  </div>
);

// Capsule CTA
const CapsuleCTA = ({ label, tint = '#3378F5', icon, onClick, wide, solid = true }) => (
  <Pressable onClick={onClick} style={{
    display:'inline-flex', alignItems:'center', justifyContent:'center', gap:8,
    padding: wide ? '14px 22px' : '10px 14px',
    borderRadius: 999,
    background: solid ? `linear-gradient(180deg, ${lighten(tint)} 0%, ${tint} 100%)` : 'transparent',
    color: solid ? '#fff' : tint,
    fontWeight: 800, fontFamily:'Nunito, system-ui', fontSize: wide?16:13, whiteSpace:'nowrap',
    border: solid ? 0 : `1.5px solid ${tint}`,
  }}>
    {label}
    {icon && <Icon name={icon} size={14} color={solid?'#fff':tint} strokeWidth={3}/>}
  </Pressable>
);

function lighten(hex) {
  // crude 30% lighten for capsule gradient top-stop
  const map = { '#3378F5':'#5E9BFF', '#F28C26':'#FFB066', '#249970':'#4FC49A', '#526EF0':'#7D92F5', '#8F47EB':'#BF87FA' };
  return map[hex] || hex;
}

// Micro label
const MicroLabel = ({ children, style }) => (
  <div style={{
    fontFamily:'Nunito, system-ui', fontSize:10, fontWeight:800,
    letterSpacing:0.8, textTransform:'uppercase', color:'#697382', ...style
  }}>{children}</div>
);

// Mode metadata (single source of truth)
const MODES = {
  timed:       { label:'Timed Practice',   icon:'timer',    tint:'#3378F5', cta:'Start', sub:'Choose a difficulty, take a beat, and build a full answer with structure.', outcome:'Best for fuller, cleaner complete answers.', fit:'Helps when your answers end early or lose structure.' },
  suddenDeath: { label:'Sudden Death',     icon:'bolt',     tint:'#F28C26', cta:'Begin', sub:'Start immediately and stay alive without a single filler word.',      outcome:'Best for pressure tolerance and quick thinking.', fit:'Strong when you freeze or want sharper composure on the spot.' },
  ahCounter:   { label:'Ah-Counter',       icon:'waveform', tint:'#249970', cta:'Start', sub:'Speak freely while Noum tracks fillers and pacing in real time.',     outcome:'Best for reducing fillers and calming rushed delivery.', fit:'Strong when you need cleaner openings and steadier rhythm.' },
  imConv:      { label:'IM Mode',          icon:'message',  tint:'#526EF0', cta:'Begin', sub:'Train tone, pacing, realism, and relationship impact inside a live conversation.', outcome:'Best for real-world communication and tone control.', fit:'Strong when you want realistic social, work, or pressure reps.' },
};

Object.assign(window, { Icon, Card, Pressable, ShimmerBar, PulseBadge, SparkleRibbon, CapsuleCTA, MicroLabel, MODES, lighten });
