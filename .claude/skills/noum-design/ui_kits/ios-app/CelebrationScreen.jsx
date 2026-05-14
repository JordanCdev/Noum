// Celebration screen — Personal Best hero card.
// Distinct surface from the daily Progress screen — used only for personal-best
// moments (lifted from Noum/CelebrationViews.swift + TierPromotionOverlay.swift).
// Visual language: premium pro purple (canonical AppColor.pro / proLight),
// frosted-glass stat tiles, white capsule CTA. Uses the same primitives,
// spacing, radii, and Nunito type as the rest of the kit so it sits next to
// the Progress and Summary screens without looking grafted on.

const PRO        = '#8F47EB';
const PRO_LIGHT  = '#D185FF';
const PRO_DEEP   = '#5E2EAB';
const SECONDARY  = '#697382';

// Five-point sparkle that matches the SF Symbol `sparkle` shape language Noum
// uses elsewhere (also see SparkleRibbon in Primitives.jsx). Single-tint, no
// stroke — pure foreground glyph, opacity-driven.
const SparkleStar = ({ size = 12, color = 'rgba(255,255,255,0.85)' }) => (
  <svg width={size} height={size} viewBox="-1.15 -1.15 2.3 2.3" aria-hidden="true">
    <path
      d="M0,-1 C-0.06,-0.2 -0.2,-0.06 -1,0 C-0.2,0.06 -0.06,0.2 0,1 C0.06,0.2 0.2,0.06 1,0 C0.2,-0.06 0.06,-0.2 0,-1 Z"
      fill={color}
    />
  </svg>
);

// Spatial sparkle cluster — 5 stars in the top-right corner, each twinkling on
// its own staggered loop. Mirrors PulseBadge / SparkleRibbon timing (1.8s).
const SparkleCluster = () => {
  const cfg = [
    { size: 14, left: 22, top: 0,  delay: 0     },
    { size:  7, left:  6, top: 4,  delay: 0.36  },
    { size: 10, left: 30, top: 16, delay: 0.72  },
    { size:  6, left:  0, top: 14, delay: 0.18  },
    { size: 11, left: 14, top: 26, delay: 1.08  },
  ];
  return (
    <div style={{position:'relative',width:44,height:40,flexShrink:0}}>
      {cfg.map((s, i) => (
        <div key={i} style={{
          position:'absolute',left:s.left,top:s.top,
          animation:`noum-twinkle 1.8s ease-in-out ${s.delay}s infinite`,
        }}>
          <SparkleStar size={s.size}/>
        </div>
      ))}
    </div>
  );
};

// Frosted-glass stat tile sitting on top of the purple hero. White text @ 100%
// is reserved for the CTA, so values use white @ 100% but labels drop to 72%.
const FrostedStat = ({ value, label }) => (
  <div style={{
    flex:1,
    background:'rgba(255,255,255,0.10)',
    border:'1px solid rgba(255,255,255,0.20)',
    borderRadius:18,
    padding:16,
  }}>
    <div style={{
      fontFamily:'Nunito,system-ui',
      fontSize:30,fontWeight:800,color:'#FFFFFF',lineHeight:1.05,
      letterSpacing:'-0.01em',marginBottom:4,
    }}>{value}</div>
    <div style={{
      fontFamily:'Nunito,system-ui',
      fontSize:13,fontWeight:600,color:'rgba(255,255,255,0.72)',
    }}>{label}</div>
  </div>
);

// The hero card itself. Standalone — drop into any screen / overlay context.
const PersonalBestCard = ({ onReview }) => (
  <div style={{
    position:'relative',
    isolation:'isolate',
    borderRadius:28,
    padding:'28px 24px',
    overflow:'hidden',
    background:`linear-gradient(135deg, ${PRO} 0%, ${PRO_DEEP} 100%)`,
    boxShadow:[
      'inset 0 1px 0 rgba(255,255,255,0.22)',
      `0 12px 24px -8px ${PRO}59`,
      `0 28px 56px -12px ${PRO}73`,
    ].join(', '),
    animation:'noum-celebration-in 600ms cubic-bezier(0.16,1,0.3,1) both',
  }}>
    {/* Mesh layer 1 — white radial highlight from top-left */}
    <div style={{
      position:'absolute',inset:0,pointerEvents:'none',
      background:'radial-gradient(ellipse 85% 68% at 0% 0%, rgba(255,255,255,0.30) 0%, transparent 72%)',
      mixBlendMode:'plus-lighter',
    }}/>
    {/* Mesh layer 2 — pro-light radial from top-right */}
    <div style={{
      position:'absolute',inset:0,pointerEvents:'none',
      background:`radial-gradient(ellipse 72% 58% at 100% 0%, ${PRO_LIGHT}8C 0%, transparent 68%)`,
      mixBlendMode:'plus-lighter',
    }}/>
    {/* Specular gloss across the top 38% */}
    <div style={{
      position:'absolute',top:0,left:0,right:0,height:'38%',pointerEvents:'none',
      background:'linear-gradient(180deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0) 100%)',
      borderRadius:'28px 28px 0 0',
    }}/>

    {/* Content */}
    <div style={{position:'relative',zIndex:1}}>
      {/* Kicker + sparkle cluster */}
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:16}}>
        <span style={{
          fontFamily:'Nunito,system-ui',
          fontSize:10,fontWeight:800,color:'rgba(255,255,255,0.72)',
          textTransform:'uppercase',letterSpacing:0.8,paddingTop:2,
        }}>Personal best · This week</span>
        <SparkleCluster/>
      </div>

      {/* Headline */}
      <div style={{
        fontFamily:'Nunito,system-ui',
        fontSize:28,fontWeight:800,color:'#FFFFFF',
        letterSpacing:'-0.015em',lineHeight:1.18,marginBottom:10,
      }}>
        A clean rep at full pressure.
      </div>

      {/* Body */}
      <div style={{
        fontFamily:'Nunito,system-ui',
        fontSize:15,fontWeight:500,color:'rgba(255,255,255,0.72)',
        maxWidth:'24ch',lineHeight:1.5,marginBottom:22,
      }}>
        No filler words across the full two-minute block.
      </div>

      {/* Frosted stat tiles */}
      <div style={{display:'flex',gap:12,marginBottom:18}}>
        <FrostedStat value="98"  label="Score"/>
        <FrostedStat value="+12" label="vs last rep"/>
      </div>

      {/* CTA — filled white. The only place white is foreground in this card. */}
      <Pressable onClick={onReview} style={{
        width:'100%',
        padding:'15px 20px',
        borderRadius:999,
        background:'#FFFFFF',
        color:PRO,
        fontFamily:'Nunito,system-ui',
        fontSize:16,fontWeight:800,letterSpacing:'-0.005em',
        display:'flex',alignItems:'center',justifyContent:'center',gap:6,
      }}>
        Review this rep
        <Icon name="chevron" size={16} color={PRO} strokeWidth={2.6}/>
      </Pressable>
    </div>
  </div>
);

// Screen wrapper — shows the hero in context with the same back-bar +
// "Just now" timestamp pattern used by SummaryScreen, so it slots into the
// click-through without feeling like a different app.
const CelebrationScreen = ({ onNavigate }) => (
  <div style={{...homeStyles.screen, background:'#F2F2F7'}}>
    <div style={{position:'absolute',inset:0,overflowY:'auto',overflowX:'hidden',WebkitOverflowScrolling:'touch'}}>
      <div style={{padding:'62px 20px 130px'}}>

        {/* Top bar — match Summary/Progress */}
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:18}}>
          <Pressable onClick={()=>onNavigate('home')} style={{
            color:SECONDARY,fontWeight:700,fontSize:14,
            display:'flex',alignItems:'center',gap:4,fontFamily:'Nunito,system-ui',
          }}>
            <Icon name="chevron" size={14} color={SECONDARY} strokeWidth={3} style={{transform:'rotate(180deg)'}}/>
            Home
          </Pressable>
          <div style={{fontSize:13,color:SECONDARY,fontWeight:700,fontFamily:'Nunito,system-ui'}}>Just now · Timed Practice</div>
          <div style={{width:48}}/>
        </div>

        {/* Hero header — matches the ProgressScreen pattern */}
        <MicroLabel style={{marginBottom:6}}>Today's milestone</MicroLabel>
        <div style={{fontFamily:'Nunito,system-ui',fontSize:26,fontWeight:700,color:'#212633',lineHeight:1.18,marginBottom:18}}>
          You hit a new personal best.
        </div>

        {/* The card */}
        <PersonalBestCard onReview={()=>onNavigate('summary','timed')}/>

        {/* Secondary action — ghost capsule, low-key, doesn't compete with the white CTA */}
        <div style={{marginTop:18,display:'flex',justifyContent:'center'}}>
          <Pressable onClick={()=>onNavigate('progress')} style={{
            display:'inline-flex',alignItems:'center',gap:6,
            padding:'12px 18px',borderRadius:999,
            color:SECONDARY,fontFamily:'Nunito,system-ui',fontWeight:700,fontSize:14,
          }}>
            See all milestones
            <Icon name="chevron" size={12} color={SECONDARY} strokeWidth={3}/>
          </Pressable>
        </div>

      </div>
    </div>
  </div>
);

Object.assign(window, { CelebrationScreen, PersonalBestCard, FrostedStat, SparkleCluster });
