// Progress hero — last-rep Grading card + Milestones strip
// Faithful build of the Figma prompt at docs/figma-prompts/milestones-grading-hero
// Uses primitives from Primitives.jsx; matches Summary/Home visual language.

const ProgressScreen = ({ onNavigate }) => {
  const cur = MODES.timed; // graded session was a Timed Practice rep

  // Animated count-up from 0 → 8.6 over ~0.8s ease-out
  const [score, setScore] = useState(0);
  useEffect(() => {
    const target = 8.6, duration = 800, start = performance.now();
    let raf;
    const tick = (t) => {
      const k = Math.min(1, (t - start) / duration);
      const eased = 1 - Math.pow(1 - k, 3); // easeOutCubic
      setScore(+(eased * target).toFixed(1));
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  const ringPct = score / 10; // 0..1
  const ringSize = 132, ringStroke = 10;
  const r = (ringSize - ringStroke) / 2;
  const c = 2 * Math.PI * r;
  const dash = c * ringPct;

  const milestones = [
    { id:'streak',   track:'Consistency', tint:'#F28C26', icon:'flame',    title:'7-Day Streak',         frac:'5 / 7',  pct:5/7, isNew:true  },
    { id:'clean',    track:'Clarity',     tint:'#3378F5', icon:'mic_clean',title:'Zero-Filler Rep',      unlocked:true                          },
    { id:'high',     track:'Scores',      tint:'#D4851A', icon:'target',   title:'Score 9+ three times', frac:'1 / 3',  pct:1/3                 },
    { id:'rank',     track:'Mastery',     tint:'#697382', icon:'crown',    title:'Speaker Rank 5',       locked:true                            },
    { id:'volume',   track:'Volume',      tint:'#249970', icon:'dumbbell', title:'10 Sessions',          frac:'7 / 10', pct:7/10                },
  ];

  return (
    <div style={{...homeStyles.screen, background:'#F2F2F7'}}>
      <div style={{position:'absolute',inset:0,overflowY:'auto',overflowX:'hidden',WebkitOverflowScrolling:'touch'}}>
        <div style={{padding:'62px 20px 130px'}}>

          {/* Top bar — back + section label */}
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:14}}>
            <Pressable onClick={()=>onNavigate('home')} style={{color:'#697382',fontWeight:700,fontSize:14,display:'flex',alignItems:'center',gap:4,fontFamily:'Nunito,system-ui'}}>
              <Icon name="chevron" size={14} color="#697382" strokeWidth={3} style={{transform:'rotate(180deg)'}}/>
              Home
            </Pressable>
            <div style={{fontSize:13,color:'#697382',fontWeight:700,fontFamily:'Nunito,system-ui'}}>Your progress</div>
            <div style={{width:48}}/>
          </div>

          {/* Hero header */}
          <MicroLabel style={{marginBottom:6}}>Your last rep</MicroLabel>
          <div style={{fontFamily:'Nunito,system-ui',fontSize:26,fontWeight:700,color:'#212633',lineHeight:1.18,marginBottom:14}}>
            Clear step up from your recent baseline.
          </div>

          {/* GRADING CARD */}
          <Card xl tintShadow={cur.tint} style={{marginBottom:18,position:'relative'}}>
            {/* Mode chip row */}
            <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:14}}>
              <div style={{width:28,height:28,borderRadius:9,background:`${cur.tint}1f`,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <Icon name="timer" size={14} color={cur.tint} strokeWidth={2.5}/>
              </div>
              <MicroLabel style={{color:cur.tint}}>Timed Practice</MicroLabel>
            </div>

            {/* Score ring */}
            <div style={{display:'flex',justifyContent:'center',marginBottom:14,position:'relative'}}>
              <div style={{position:'relative',width:ringSize,height:ringSize}}>
                <svg width={ringSize} height={ringSize} style={{transform:'rotate(-90deg)'}}>
                  <circle cx={ringSize/2} cy={ringSize/2} r={r}
                    stroke={`${cur.tint}1a`} strokeWidth={ringStroke} fill="none"/>
                  <circle cx={ringSize/2} cy={ringSize/2} r={r}
                    stroke={cur.tint} strokeWidth={ringStroke} fill="none"
                    strokeLinecap="round"
                    strokeDasharray={`${dash} ${c-dash}`}
                    style={{transition:'stroke-dasharray 60ms linear'}}/>
                </svg>
                {/* Specular shimmer overlay on filled arc */}
                <div style={{
                  position:'absolute',inset:0,borderRadius:'50%',
                  background:`conic-gradient(from 0deg, transparent 0deg, rgba(255,255,255,0.4) 14deg, transparent 28deg, transparent 360deg)`,
                  mask:`radial-gradient(circle, transparent ${r-ringStroke/2}px, #000 ${r-ringStroke/2}px, #000 ${r+ringStroke/2}px, transparent ${r+ringStroke/2}px)`,
                  WebkitMask:`radial-gradient(circle, transparent ${r-ringStroke/2}px, #000 ${r-ringStroke/2}px, #000 ${r+ringStroke/2}px, transparent ${r+ringStroke/2}px)`,
                  animation:'noum-ring-shimmer 2.4s linear infinite',
                  opacity:0.55,
                }}/>
                <div style={{position:'absolute',inset:0,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center'}}>
                  <div style={{fontFamily:'Nunito,system-ui',fontSize:44,fontWeight:800,color:cur.tint,lineHeight:1,letterSpacing:'-0.01em'}}>{score.toFixed(1)}</div>
                  <div style={{fontSize:12,fontWeight:700,color:'#697382',marginTop:4}}>/ 10</div>
                </div>
              </div>
            </div>

            {/* Headline + quote */}
            <div style={{fontFamily:'Nunito,system-ui',fontSize:18,fontWeight:700,color:'#212633',textAlign:'center',marginBottom:6}}>
              Strong session. Controlled and clear.
            </div>
            <div style={{fontSize:13,fontStyle:'italic',color:'#697382',textAlign:'center',lineHeight:1.45,marginBottom:16,padding:'0 8px'}}>
              "The trick to a great answer is to start before you're ready."
            </div>

            {/* Stat pills */}
            <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10,marginBottom:14}}>
              <StatPill label="Fillers"  value="2"   delta="-3"   deltaDir="down" good/>
              <StatPill label="Duration" value="47s" delta="+12s" deltaDir="up"   good/>
              <StatPill label="XP"       value="+85" delta="+15"  deltaDir="up"   good/>
            </div>

            {/* Coach note */}
            <div style={{background:'#F7F7FA',borderRadius:18,padding:'12px 14px',display:'flex',gap:10,alignItems:'flex-start'}}>
              <div style={{width:26,height:26,borderRadius:8,background:'rgba(25,153,102,0.14)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:1}}>
                <Icon name="trending_up" size={14} color="#199966" strokeWidth={2.6}/>
              </div>
              <div style={{flex:1,minWidth:0}}>
                <MicroLabel style={{color:'#199966',marginBottom:2}}>Momentum</MicroLabel>
                <div style={{fontSize:13.5,color:'#212633',lineHeight:1.45,fontWeight:500}}>
                  Your filler count dropped from 8 to 2 — that's a meaningful shift.
                </div>
              </div>
            </div>
          </Card>

          {/* MILESTONES section header */}
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',marginBottom:10,paddingLeft:2,paddingRight:2}}>
            <MicroLabel>Milestones</MicroLabel>
            <div style={{fontSize:12,fontWeight:700,color:'#697382',fontFamily:'Nunito,system-ui'}}>4 of 32 unlocked</div>
          </div>

          {/* Milestones strip — horizontal scroll */}
          <div style={{
            display:'flex',gap:12,overflowX:'auto',overflowY:'hidden',
            margin:'0 -20px',padding:'4px 20px 18px',
            scrollbarWidth:'none',
          }}>
            {milestones.map((m, i) => (
              <MilestoneTile key={m.id} m={m} delay={i*60}/>
            ))}
          </div>

          {/* NEXT MILESTONE card */}
          <Pressable onClick={()=>onNavigate('modes')} style={{
            background:'#fff',borderRadius:24,padding:'16px 18px',
            border:'1.2px solid',
            borderImage:`linear-gradient(135deg, rgba(255,255,255,.9), ${MODES.suddenDeath.tint}33) 1`,
            boxShadow:`0 8px 20px ${MODES.suddenDeath.tint}1a`,
            display:'flex',alignItems:'center',gap:14,
          }}>
            <PulseBadge name="flame" tint={MODES.suddenDeath.tint} size={48}/>
            <div style={{flex:1,minWidth:0}}>
              <MicroLabel style={{color:MODES.suddenDeath.tint,marginBottom:3}}>Next milestone</MicroLabel>
              <div style={{fontFamily:'Nunito,system-ui',fontSize:16,fontWeight:800,color:'#212633',lineHeight:1.25}}>
                Two more reps for your 7-Day Streak.
              </div>
              <div style={{fontSize:12.5,color:'#697382',marginTop:3,lineHeight:1.4}}>
                Most people stop at 3. Keep the pattern going.
              </div>
            </div>
            <div style={{width:32,height:32,borderRadius:'50%',background:`${MODES.suddenDeath.tint}14`,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name="chevron" size={14} color={MODES.suddenDeath.tint} strokeWidth={3}/>
            </div>
          </Pressable>

        </div>
      </div>
    </div>
  );
};

// --- Stat pill ---------------------------------------------------------------
const StatPill = ({ label, value, delta, deltaDir, good }) => {
  const deltaColor = good ? '#199966' : '#BD3833';
  const arrow = deltaDir === 'down' ? '↓' : '↑';
  return (
    <div style={{background:'#F7F7FA',borderRadius:18,padding:'12px 10px',display:'flex',flexDirection:'column',gap:4,alignItems:'flex-start'}}>
      <div style={{fontSize:10.5,fontWeight:800,letterSpacing:0.6,textTransform:'uppercase',color:'#697382',fontFamily:'Nunito,system-ui'}}>{label}</div>
      <div style={{display:'flex',alignItems:'baseline',gap:6,flexWrap:'wrap'}}>
        <span style={{fontFamily:'Nunito,system-ui',fontSize:18,fontWeight:800,color:'#212633',lineHeight:1}}>{value}</span>
        <span style={{
          fontSize:11,fontWeight:800,color:deltaColor,
          background:`${deltaColor}1a`,padding:'2px 6px',borderRadius:6,
          display:'inline-flex',alignItems:'center',gap:2,whiteSpace:'nowrap',
        }}>
          <span style={{fontSize:10,lineHeight:1}}>{arrow}</span>{delta}
        </span>
      </div>
    </div>
  );
};

// --- Milestone tile ----------------------------------------------------------
const MilestoneTile = ({ m, delay = 0 }) => {
  const dim = m.locked;
  const tileTint = dim ? '#9aa3b2' : m.tint;
  return (
    <div style={{
      flex:'0 0 156px',background:'#fff',borderRadius:20,padding:14,
      border:'1px solid rgba(15,23,42,0.04)',
      boxShadow:`0 8px 18px -10px ${tileTint}44`,
      position:'relative',display:'flex',flexDirection:'column',gap:10,
      animation:`noum-tile-pop 520ms cubic-bezier(0.2,1.2,0.35,1) both`,
      animationDelay:`${delay}ms`,
      opacity:dim ? 0.7 : 1,
    }}>
      {/* NEW chip */}
      {m.isNew && (
        <div style={{
          position:'absolute',top:10,right:10,
          fontSize:9.5,fontWeight:800,letterSpacing:0.6,textTransform:'uppercase',
          color:m.tint,background:`${m.tint}1f`,padding:'3px 7px',borderRadius:999,
          fontFamily:'Nunito,system-ui',
          animation:'noum-new-lift 520ms cubic-bezier(0.2,1.2,0.35,1) both',
          animationDelay:`${delay + 220}ms`,
        }}>New</div>
      )}

      {/* Icon disc */}
      <div style={{
        width:52,height:52,borderRadius:15,
        background:dim ? 'rgba(105,115,130,0.10)' : `${m.tint}1f`,
        display:'flex',alignItems:'center',justifyContent:'center',
        position:'relative',
      }}>
        <Icon name={m.icon} size={24} color={tileTint} strokeWidth={2.2}/>
        {m.unlocked && (
          <div style={{position:'absolute',bottom:-4,right:-4,width:20,height:20}}>
            <Icon name="check" size={20} color="#199966" strokeWidth={0}/>
          </div>
        )}
      </div>

      {/* Track + title */}
      <div style={{display:'flex',flexDirection:'column',gap:3}}>
        <div style={{fontSize:10,fontWeight:800,letterSpacing:0.6,textTransform:'uppercase',color:tileTint,fontFamily:'Nunito,system-ui'}}>{m.track}</div>
        <div style={{fontFamily:'Nunito,system-ui',fontSize:14,fontWeight:800,color:dim?'#697382':'#212633',lineHeight:1.25,minHeight:34}}>
          {m.title}
        </div>
      </div>

      {/* Progress / state */}
      {m.unlocked ? (
        <div style={{fontSize:11,fontWeight:800,color:'#199966',fontFamily:'Nunito,system-ui',marginTop:'auto'}}>Unlocked</div>
      ) : m.locked ? (
        <div style={{fontSize:11,fontWeight:700,color:'#9aa3b2',fontFamily:'Nunito,system-ui',marginTop:'auto'}}>Locked</div>
      ) : (
        <div style={{marginTop:'auto'}}>
          <div style={{height:4,borderRadius:4,background:`${m.tint}1a`,overflow:'hidden',marginBottom:5}}>
            <div style={{width:`${Math.round(m.pct*100)}%`,height:'100%',background:m.tint,borderRadius:4,transition:'width 600ms ease'}}/>
          </div>
          <div style={{fontSize:11,fontWeight:700,color:'#697382',fontFamily:'Nunito,system-ui'}}>{m.frac}</div>
        </div>
      )}
    </div>
  );
};

Object.assign(window, { ProgressScreen, StatPill, MilestoneTile });
