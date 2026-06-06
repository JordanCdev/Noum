// Practice Mode Selection + Practice (mic) + Summary + Login screens

// Duotone glyph language — same as Communication Profile
// Soft fill + clean stroke. Pass tint via `color` prop.
const ModeGlyph = ({ name, size = 24, color = 'currentColor' }) => {
  const sw = 1.85;
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: color, strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'timer':
      return <svg {...props}>
        {/* clock face filled */}
        <circle cx="12" cy="13.5" r="8" fill={color} fillOpacity="0.2"/>
        <circle cx="12" cy="13.5" r="8"/>
        {/* hands */}
        <path d="M12 13.5V8.5"/>
        <path d="M12 13.5l3.4 1.6" opacity="0.7"/>
        {/* crown */}
        <rect x="9.5" y="2" width="5" height="2.5" rx="1" fill={color} stroke="none"/>
        <path d="M10 2v2.5M14 2v2.5"/>
      </svg>;
    case 'bolt':
      return <svg {...props}>
        <path d="M13 2 L4 14 L11 14 L10 22 L20 10 L13 10 Z" fill={color} fillOpacity="0.22"/>
        <path d="M13 2 L4 14 L11 14 L10 22 L20 10 L13 10 Z"/>
      </svg>;
    case 'wave':
      return <svg {...props}>
        {/* container box for visual weight */}
        <rect x="3" y="6" width="18" height="12" rx="3" fill={color} fillOpacity="0.18"/>
        {/* bars */}
        <path d="M6 12h.01M9 9v6M12 6v12M15 8v8M18 11v2" strokeWidth="2.4"/>
      </svg>;
    case 'message':
      return <svg {...props}>
        <path d="M4 6h14a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H10l-4 4v-4H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z" fill={color} fillOpacity="0.22"/>
        <path d="M4 6h14a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H10l-4 4v-4H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/>
        {/* dots inside bubble */}
        <circle cx="8" cy="11" r="0.9" fill={color} stroke="none"/>
        <circle cx="11.5" cy="11" r="0.9" fill={color} stroke="none"/>
        <circle cx="15" cy="11" r="0.9" fill={color} stroke="none"/>
      </svg>;
    default: return null;
  }
};

const MODE_GLYPH = { timed:'timer', suddenDeath:'bolt', ahCounter:'wave', imConv:'message' };
const MODE_BEST  = { timed:'Best for structure', suddenDeath:'Best under pressure', ahCounter:'Best for cleaner reps', imConv:'Best for tone & realism' };

const ModePickerScreen = ({ onNavigate }) => {
  const [selected, setSelected] = useState('timed');
  const modes = ['timed','suddenDeath','ahCounter','imConv'];
  const recommended = 'timed';
  const cur = MODES[selected];

  return (
    <div style={{...homeStyles.screen, background:'#F4F4F8', position:'relative'}}>
      {/* SCROLL AREA — explicit pad-bottom that clears the docked CTA */}
      <div style={{padding:'62px 20px 140px'}}>
        <Pressable onClick={()=>onNavigate('home')} style={{display:'inline-flex',alignItems:'center',gap:6,padding:'6px 0',marginBottom:14,color:'#3378F5',fontFamily:"'Manrope',system-ui",fontWeight:700,fontSize:13,letterSpacing:0.3}}>
          <span style={{transform:'scaleX(-1)',display:'inline-block'}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#3378F5" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>
          </span>
          BACK
        </Pressable>

        <div style={{marginBottom:6}}>
          <div style={{fontFamily:"'Manrope',system-ui",fontWeight:700,fontSize:11,letterSpacing:1.1,textTransform:'uppercase',color:'#697382'}}>Practice</div>
          <div style={{fontFamily:"'Figtree',system-ui",fontSize:30,fontWeight:800,color:'#212633',lineHeight:1.1,letterSpacing:'-0.02em',marginTop:4}}>Choose your next rep</div>
        </div>

        <div style={{fontFamily:"'Manrope',system-ui",fontWeight:500,fontSize:14,color:'#3a4253',marginTop:10,marginBottom:22,lineHeight:1.45}}>
          Each mode trains a different kind of pressure.
        </div>

        {/* All drills list — uses the new mode-card design language */}
        <div style={{display:'flex',flexDirection:'column',gap:10}}>
          {modes.map(m => {
            const mode = MODES[m];
            const sel = selected === m;
            const rec = m === recommended;
            return (
              <Pressable key={m} onClick={()=>setSelected(m)}>
                <div style={{
                  position:'relative',
                  background:'#fff',
                  borderRadius:22,
                  padding:18,
                  display:'flex',alignItems:'center',gap:14,
                  border: sel ? `1.5px solid ${mode.tint}` : '1px solid rgba(15,23,42,0.04)',
                  boxShadow: sel
                    ? `0 1px 0 rgba(15,23,42,0.03), 0 14px 30px -14px ${mode.tint}55`
                    : '0 1px 0 rgba(15,23,42,0.03), 0 8px 22px -12px rgba(15,23,42,0.14)',
                  overflow:'hidden',
                  transition:'border-color 240ms ease, box-shadow 240ms ease',
                }}>
                  {/* Soft tint wash on the left */}
                  <div style={{position:'absolute',inset:0,pointerEvents:'none',
                    background:`radial-gradient(120% 100% at 0% 50%, ${mode.tint}14, transparent 55%)`}}/>

                  {/* Hero glyph */}
                  <div style={{
                    position:'relative',width:52,height:52,borderRadius:15,flexShrink:0,
                    display:'flex',alignItems:'center',justifyContent:'center',
                    background:`${mode.tint}1f`,color:mode.tint,
                  }}>
                    <ModeGlyph name={MODE_GLYPH[m]} size={24} color={mode.tint}/>
                    {/* gloss */}
                    <div style={{position:'absolute',inset:0,borderRadius:15,
                      background:'linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0) 60%)',pointerEvents:'none'}}/>
                  </div>

                  {/* Body */}
                  <div style={{position:'relative',flex:1,minWidth:0,display:'flex',flexDirection:'column',gap:3}}>
                    <div style={{display:'flex',alignItems:'center',gap:8,flexWrap:'wrap'}}>
                      <span style={{fontFamily:"'Figtree',system-ui",fontSize:17,fontWeight:800,color:'#212633',letterSpacing:'-0.005em'}}>{mode.label}</span>
                      {rec && (
                        <span style={{fontFamily:"'Manrope',system-ui",fontSize:9.5,fontWeight:800,color:mode.tint,background:`${mode.tint}1a`,padding:'3px 7px',borderRadius:999,letterSpacing:0.6,textTransform:'uppercase'}}>For you</span>
                      )}
                    </div>
                    <div style={{display:'flex',alignItems:'center',gap:8,fontFamily:"'Manrope',system-ui",fontWeight:600,fontSize:12,color:'#697382'}}>
                      <span style={{color:mode.tint,fontWeight:700}}>{MODE_BEST[m]}</span>
                    </div>
                  </div>

                  {/* Selection indicator — refined dot/ring */}
                  <div style={{position:'relative',flexShrink:0,width:24,height:24,display:'flex',alignItems:'center',justifyContent:'center'}}>
                    <div style={{
                      width:22,height:22,borderRadius:'50%',
                      border:sel ? `1.5px solid ${mode.tint}` : '1.5px solid rgba(15,23,42,0.15)',
                      background:sel ? mode.tint : 'transparent',
                      display:'flex',alignItems:'center',justifyContent:'center',
                      transition:'all 240ms cubic-bezier(0.2,1,0.3,1)',
                    }}>
                      {sel && (
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round">
                          <path d="M5 12.5l4.5 4.5L20 6.5"/>
                        </svg>
                      )}
                    </div>
                  </div>
                </div>
              </Pressable>
            );
          })}
        </div>
      </div>

      {/* DOCKED START BAR */}
      <div style={{
        position:'absolute',left:14,right:14,bottom:14,
        background:'rgba(255,255,255,0.96)',backdropFilter:'blur(20px)',
        borderRadius:24,border:'1px solid rgba(15,23,42,0.06)',
        padding:'10px 12px 10px 14px',display:'flex',alignItems:'center',gap:12,
        boxShadow:'0 -10px 30px -8px rgba(15,23,42,0.18), 0 1px 0 rgba(15,23,42,0.04), 0 14px 36px -10px rgba(15,23,42,0.18)',
        zIndex:5,
      }}>
        <div style={{
          width:40,height:40,borderRadius:13,flexShrink:0,
          display:'flex',alignItems:'center',justifyContent:'center',
          background:`${cur.tint}1f`,color:cur.tint,
        }}>
          <ModeGlyph name={MODE_GLYPH[selected]} size={20} color={cur.tint}/>
        </div>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontFamily:"'Manrope',system-ui",fontWeight:700,fontSize:10.5,color:'#697382',letterSpacing:0.8,textTransform:'uppercase'}}>Selected</div>
          <div style={{fontFamily:"'Figtree',system-ui",fontSize:15,fontWeight:800,color:'#212633',marginTop:1,letterSpacing:'-0.005em'}}>{cur.label}</div>
        </div>
        <Pressable onClick={()=>onNavigate('practice',selected)} style={{
          display:'inline-flex',alignItems:'center',gap:8,
          padding:'12px 18px',borderRadius:999,
          background:`linear-gradient(180deg, ${lighten(cur.tint)} 0%, ${cur.tint} 100%)`,
          color:'#fff',fontFamily:"'Figtree',system-ui",fontWeight:800,fontSize:14,letterSpacing:'-0.005em',
        }}>
          Start
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </Pressable>
      </div>
    </div>
  );
};

const PracticeScreen = ({ mode = 'timed', onNavigate }) => {
  const cur = MODES[mode];
  const [time, setTime] = useState(0);
  useEffect(() => { const t = setInterval(()=>setTime(x=>x+1),1000); return ()=>clearInterval(t); },[]);
  const mm = String(Math.floor(time/60)).padStart(2,'0');
  const ss = String(time%60).padStart(2,'0');

  return (
    <div style={{...homeStyles.screen, background:'#F2F2F7'}}>
      <div style={{padding:'62px 20px 40px'}}>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:18}}>
          <Pressable onClick={()=>onNavigate('summary',mode)} style={{display:'flex',alignItems:'center',gap:4,color:'#697382',fontWeight:700,fontSize:14}}>
            <Icon name="x" size={18} color="#697382" strokeWidth={2.5}/>
            Stop
          </Pressable>
          <div style={{display:'flex',alignItems:'center',gap:6,padding:'6px 10px',borderRadius:999,background:`${cur.tint}1a`,color:cur.tint,fontSize:12,fontWeight:800}}>
            <Icon name={cur.icon} size={12} color={cur.tint} fill={cur.tint} strokeWidth={0}/>
            {cur.label}
          </div>
          <div style={{width:40}}/>
        </div>

        {/* Prompt card */}
        <Card xl style={{marginBottom:14}}>
          <MicroLabel style={{marginBottom:8}}>Your Prompt</MicroLabel>
          <div style={{fontFamily:'Nunito',fontSize:22,fontWeight:700,color:'#212633',lineHeight:1.3}}>
            Tell me about a decision you made this week that you're still thinking about.
          </div>
          <div style={{marginTop:14,display:'flex',gap:10}}>
            <div style={{flex:1,padding:'10px 12px',borderRadius:14,background:'#F7F7FA',textAlign:'center'}}>
              <div style={{fontFamily:'Nunito',fontSize:18,fontWeight:800,color:cur.tint}}>{mm}:{ss}</div>
              <div style={{fontSize:11,color:'#697382',marginTop:2}}>Elapsed</div>
            </div>
            <div style={{flex:1,padding:'10px 12px',borderRadius:14,background:'#F7F7FA',textAlign:'center'}}>
              <div style={{fontFamily:'Nunito',fontSize:18,fontWeight:800,color:'#212633'}}>30s</div>
              <div style={{fontSize:11,color:'#697382',marginTop:2}}>Target</div>
            </div>
            <div style={{flex:1,padding:'10px 12px',borderRadius:14,background:'#F7F7FA',textAlign:'center'}}>
              <div style={{fontFamily:'Nunito',fontSize:18,fontWeight:800,color:'#199966'}}>1</div>
              <div style={{fontSize:11,color:'#697382',marginTop:2}}>Fillers</div>
            </div>
          </div>
        </Card>

        {/* Transcript */}
        <Card xl style={{marginBottom:14, minHeight:200}}>
          <MicroLabel style={{marginBottom:10}}>Live Transcript</MicroLabel>
          <div style={{fontSize:16,lineHeight:1.55,color:'#212633'}}>
            So this week I had to decide whether to ship the recommendation engine before the model was fully dialed in, and, <span style={{background:'#BD383322',color:'#BD3833',padding:'0 4px',borderRadius:4,fontWeight:700}}>um</span>, it was really a tradeoff between learning faster from real users or waiting to avoid...
            <span style={{display:'inline-block',width:10,height:18,background:cur.tint,marginLeft:4,verticalAlign:'middle',animation:'noum-blink 0.9s steps(2) infinite'}}/>
          </div>
        </Card>

        {/* Big record button */}
        <div style={{display:'flex',justifyContent:'center',margin:'30px 0 10px'}}>
          <div style={{position:'relative',width:110,height:110,display:'flex',alignItems:'center',justifyContent:'center'}}>
            <div style={{position:'absolute',inset:0,borderRadius:'50%',background:`${cur.tint}1f`,animation:'noum-pulse-ring 1.6s ease-in-out infinite'}}/>
            <div style={{position:'absolute',inset:10,borderRadius:'50%',background:`${cur.tint}2e`,animation:'noum-pulse-fill 1.6s ease-in-out infinite'}}/>
            <Pressable onClick={()=>onNavigate('summary',mode)} style={{width:82,height:82,borderRadius:'50%',background:`linear-gradient(180deg, ${lighten(cur.tint)}, ${cur.tint})`,display:'flex',alignItems:'center',justifyContent:'center',boxShadow:`0 12px 30px ${cur.tint}66`}}>
              <Icon name="pause" size={32} color="#fff" fill="#fff" strokeWidth={0}/>
            </Pressable>
          </div>
        </div>
        <div style={{textAlign:'center',fontSize:13,color:'#697382',fontWeight:700}}>Tap to stop and get your score</div>
      </div>
    </div>
  );
};

const SummaryScreen = ({ mode = 'timed', onNavigate }) => {
  const cur = MODES[mode];
  return (
    <div style={{...homeStyles.screen, background:'#F2F2F7'}}>
      <div style={{padding:'62px 20px 40px'}}>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:14}}>
          <Pressable onClick={()=>onNavigate('home')} style={{color:'#697382',fontWeight:700,fontSize:14,display:'flex',alignItems:'center',gap:4}}>
            <Icon name="chevron" size={14} color="#697382" strokeWidth={3} style={{transform:'rotate(180deg)'}}/>
            Home
          </Pressable>
          <div style={{fontSize:13,color:'#697382',fontWeight:700}}>Just now · {cur.label}</div>
        </div>

        {/* Score hero */}
        <Card xl style={{marginBottom:14,background:`linear-gradient(135deg, ${cur.tint}14, ${cur.tint}05)`}}>
          <MicroLabel>Your Score</MicroLabel>
          <div style={{display:'flex',alignItems:'baseline',gap:8,marginTop:6}}>
            <div style={{fontFamily:'Nunito',fontSize:64,fontWeight:800,color:cur.tint,lineHeight:1}}>82</div>
            <div style={{fontSize:18,color:'#697382',fontWeight:700}}>/ 100</div>
            <div style={{marginLeft:'auto'}}><SparkleRibbon tint={cur.tint}/></div>
          </div>
          <div style={{marginTop:10,fontSize:15,fontWeight:700,color:'#212633'}}>Cleanest opening you've had this week.</div>
          <div style={{marginTop:4,fontSize:13,color:'#697382',lineHeight:1.45}}>You held the structure, pushed past 30 seconds, and kept fillers to one.</div>
        </Card>

        <div style={{display:'grid',gridTemplateColumns:'repeat(4,1fr)',gap:8,marginBottom:14}}>
          <StatTile v="1" t="Fillers" c="#199966"/>
          <StatTile v="38s" t="Duration" c="#3378F5"/>
          <StatTile v="142" t="WPM" c="#F28C26"/>
          <StatTile v="+12" t="XP" c="#8F47EB"/>
        </div>

        {/* Next rep card */}
        <div style={{background:'#fff',borderRadius:24,padding:16,border:'1.2px solid',borderImage:'linear-gradient(135deg,rgba(255,255,255,.8),rgba(51,120,245,.12)) 1',boxShadow:'0 4px 12px rgba(51,120,245,.08)',marginBottom:14}}>
          <MicroLabel style={{marginBottom:10}}>What's next</MicroLabel>
          <Pressable onClick={()=>onNavigate('practice','suddenDeath')} style={{display:'flex',gap:14,alignItems:'center',padding:'12px 14px',borderRadius:18,background:`linear-gradient(135deg, ${MODES.suddenDeath.tint}1a, ${MODES.suddenDeath.tint}0d)`,border:`1px solid ${MODES.suddenDeath.tint}1a`}}>
            <PulseBadge name="bolt" tint={MODES.suddenDeath.tint}/>
            <div style={{flex:1,minWidth:0}}>
              <div style={{fontFamily:'Nunito',fontSize:17,fontWeight:800,color:'#212633'}}>Step up into pressure</div>
              <div style={{fontSize:12,fontWeight:700,color:'#697382',marginTop:2}}>Mode: Sudden Death · Zero fillers</div>
            </div>
            <CapsuleCTA label="Begin" icon="arrow_right" tint={MODES.suddenDeath.tint}/>
          </Pressable>
        </div>

        <div style={{display:'flex',gap:10}}>
          <div style={{flex:1}}><CapsuleCTA label="Review session" tint="#697382" wide solid={false} onClick={()=>{}}/></div>
          <div style={{flex:1}}><CapsuleCTA label="Another rep" tint={cur.tint} wide icon="arrow_right" onClick={()=>onNavigate('practice',mode)}/></div>
        </div>
      </div>
    </div>
  );
};

const StatTile = ({ v, t, c }) => (
  <div style={{padding:'12px 8px',borderRadius:18,background:`${c}1a`,textAlign:'center'}}>
    <div style={{fontFamily:'Nunito',fontSize:22,fontWeight:800,color:c,lineHeight:1}}>{v}</div>
    <div style={{fontSize:11,color:'#697382',marginTop:4}}>{t}</div>
  </div>
);

const LoginScreen = ({ onNavigate }) => (
  <div style={{...homeStyles.screen, background:'linear-gradient(180deg,#14182D 0%,#1E1E3D 50%,#2D2938 100%)',color:'#fff',position:'relative',overflow:'hidden'}}>
    {/* Glow orbs */}
    <div style={{position:'absolute',width:300,height:300,borderRadius:'50%',background:'rgba(51,128,242,0.25)',filter:'blur(80px)',right:-80,top:-100,pointerEvents:'none'}}/>
    <div style={{position:'absolute',width:280,height:280,borderRadius:'50%',background:'rgba(242,166,77,0.15)',filter:'blur(70px)',left:-100,top:40,pointerEvents:'none'}}/>
    <div style={{position:'absolute',width:400,height:400,borderRadius:'50%',background:'rgba(77,140,255,0.10)',filter:'blur(100px)',left:0,bottom:-200,pointerEvents:'none'}}/>

    <div style={{position:'relative',padding:'92px 28px 40px',height:'100%',display:'flex',flexDirection:'column'}}>
      <div style={{fontFamily:'Nunito',fontSize:18,fontWeight:800,color:'rgba(255,255,255,0.5)',letterSpacing:4,textTransform:'uppercase'}}>noum</div>

      <div style={{marginTop:32,flex:1}}>
        <div style={{fontFamily:'Nunito',fontSize:40,fontWeight:800,lineHeight:1.1,color:'#fff'}}>Speak with<br/>more clarity.</div>
        <div style={{fontSize:16,fontWeight:500,color:'rgba(255,255,255,0.6)',marginTop:14,lineHeight:1.5}}>
          Practice out loud. Get real-time coaching.<br/>Sound like the person you want to be.
        </div>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:12,marginTop:20}}>
        <Pressable onClick={()=>onNavigate('home')} style={{height:54,borderRadius:18,background:'#fff',color:'#212633',display:'flex',alignItems:'center',justifyContent:'center',gap:10,fontWeight:700,fontSize:17}}>
          <Icon name="apple" size={20} color="#212633" fill="#212633" strokeWidth={0}/>
          Continue with Apple
        </Pressable>
        <Pressable onClick={()=>onNavigate('home')} style={{height:54,borderRadius:18,background:'#fff',color:'#212633',display:'flex',alignItems:'center',justifyContent:'center',gap:10,fontWeight:700,fontSize:17}}>
          <Icon name="google" size={20} color="#3378F5" fill="#3378F5" strokeWidth={0}/>
          Continue with Google
        </Pressable>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'8px 0'}}>
          <div style={{flex:1,height:1,background:'rgba(255,255,255,0.12)'}}/>
          <span style={{fontSize:12,fontWeight:500,color:'rgba(255,255,255,0.35)'}}>or</span>
          <div style={{flex:1,height:1,background:'rgba(255,255,255,0.12)'}}/>
        </div>
        <Pressable onClick={()=>onNavigate('home')} style={{textAlign:'center',padding:'10px',fontSize:15,fontWeight:500,color:'rgba(255,255,255,0.55)'}}>
          Try without an account
        </Pressable>
      </div>
    </div>
  </div>
);

Object.assign(window, { ModePickerScreen, PracticeScreen, SummaryScreen, LoginScreen, StatTile });
