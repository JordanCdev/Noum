// Home screen — greeting, rank, path, recommendation, bottom nav

const HomeScreen = ({ onNavigate }) => {
  const rank = { title: 'Speaker 3', next: 'Next: Speaker 4', progress: 0.58, xpLeft: 420, challenge: 'Clean opening streak', challengeProgress: '3 / 5' };
  const path = { progress: 'Chapter 2 · Day 4 of 7' };
  const rec = MODES.timed;

  return (
    <div style={styles.screen}>
      <div style={{position:'absolute',inset:0,overflowY:'auto',overflowX:'hidden',WebkitOverflowScrolling:'touch'}}>
      <div style={{padding:'62px 20px 130px'}}>
        {/* Hero greeting */}
        <div style={{marginBottom:14}}>
          <div style={{fontFamily:'Nunito',fontSize:26,fontWeight:700,color:'#212633'}}>Hello, Jordan</div>
          <div style={{fontSize:15,color:'#697382',marginTop:2}}>Ready to level up your speaking?</div>
        </div>

        {/* Progress / rank */}
        <Card style={{marginBottom:14}}>
          <div style={{display:'flex',gap:12,alignItems:'flex-start',marginBottom:14}}>
            <div style={{width:46,height:46,borderRadius:12,background:'rgba(51,120,245,.12)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name="shield" size={22} color="#3378F5" fill="#3378F5" strokeWidth={0}/>
            </div>
            <div style={{flex:1,minWidth:0}}>
              <MicroLabel style={{marginBottom:2,textTransform:'none',letterSpacing:0.2,fontSize:12,fontWeight:700,color:'#697382'}}>Speaking Rank</MicroLabel>
              <div style={{fontFamily:'Nunito',fontSize:26,fontWeight:800,color:'#212633'}}>{rank.title}</div>
              <div style={{fontSize:12,color:'#697382',marginTop:2}}>Open progress, unlocked achievements, and recent coaching insights</div>
            </div>
            <Icon name="chevron" size={14} color="#697382" strokeWidth={3}/>
          </div>

          <div style={{marginBottom:10}}>
            <div style={{display:'flex',justifyContent:'space-between',marginBottom:6}}>
              <span style={{fontSize:12,fontWeight:700,color:'#697382'}}>{rank.next}</span>
              <span style={{fontSize:12,fontWeight:800,color:'#3378F5'}}>{Math.round(rank.progress*100)}%</span>
            </div>
            <ShimmerBar progress={rank.progress} tint="#3378F5"/>
          </div>

          <div style={{fontSize:12,color:'#697382',marginBottom:8}}>{rank.xpLeft} XP to level up</div>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
            <span style={{fontSize:12,fontWeight:800,color:'#3378F5'}}>{rank.challenge}</span>
            <span style={{fontSize:12,fontWeight:700,color:'#697382'}}>{rank.challengeProgress}</span>
          </div>
        </Card>

        {/* Your Path */}
        <Card style={{marginBottom:14}}>
          <div style={{display:'flex',gap:12,alignItems:'center'}}>
            <div style={{width:46,height:46,borderRadius:12,background:'rgba(25,153,102,.12)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name="route" size={20} color="#199966" strokeWidth={2.5}/>
            </div>
            <div style={{flex:1}}>
              <div style={{fontFamily:'Nunito',fontSize:20,fontWeight:800,color:'#212633'}}>Your Path</div>
              <div style={{fontSize:13,fontWeight:700,color:'#199966',marginTop:2}}>{path.progress}</div>
            </div>
            <Icon name="chevron" size={14} color="#697382" strokeWidth={3}/>
          </div>
        </Card>

        {/* Recommendation */}
        <div style={{
          background:'#fff',borderRadius:24,padding:16,
          border:'1.2px solid',
          borderImage:'linear-gradient(135deg,rgba(255,255,255,.8),rgba(51,120,245,.12)) 1',
          boxShadow:'0 4px 12px rgba(51,120,245,.08)',
          marginBottom:14,
        }}>
          <MicroLabel style={{marginBottom:12}}>Recommended Practice</MicroLabel>
          <Pressable onClick={() => onNavigate('practice', 'timed')} style={{
            display:'flex',gap:14,alignItems:'center',
            padding:'12px 14px',borderRadius:18,
            background:`linear-gradient(135deg, ${rec.tint}1a, ${rec.tint}0d)`,
            border:`1px solid ${rec.tint}1a`,
          }}>
            <PulseBadge name={rec.icon} tint={rec.tint}/>
            <div style={{flex:1,minWidth:0}}>
              <div style={{fontFamily:'Nunito',fontSize:18,fontWeight:800,color:'#212633'}}>Push a sharper timed rep</div>
              <div style={{fontSize:12,fontWeight:700,color:'#697382',marginTop:2}}>Mode: Timed · 35s+</div>
            </div>
            <CapsuleCTA label="Start" icon="arrow_right" tint={rec.tint}/>
          </Pressable>
          <div style={{
            marginTop:12,padding:'12px 14px',background:'#F7F7FA',
            borderRadius:18,fontSize:14,color:'#697382',lineHeight:1.45,
          }}>
            Your control is steady. Push for a cleaner, firmer timed answer to build real speaking stamina.
          </div>
        </div>
      </div>
      </div>

      {/* Bottom nav lives OUTSIDE the scroll container so it stays put */}
      <BottomNav active="train" onNavigate={onNavigate}/>
    </div>
  );
};

// Clean duotone tab-bar glyphs — soft fill + sharp stroke, paired set
const TabGlyph = ({ name, color, size = 22 }) => {
  const sw = 1.85;
  const props = { width:size, height:size, viewBox:'0 0 24 24', fill:'none',
    stroke:color, strokeWidth:sw, strokeLinecap:'round', strokeLinejoin:'round' };
  const soft = { fill:color, fillOpacity:0.2, stroke:color, strokeWidth:sw, strokeLinejoin:'round', strokeLinecap:'round' };
  switch (name) {
    case 'train':    // mic — clean speaker training metaphor
      return <svg {...props}>
        <rect x="9" y="3" width="6" height="11" rx="3" {...soft}/>
        <path d="M5.5 11a6.5 6.5 0 0 0 13 0"/>
        <path d="M12 17.5V21"/>
        <path d="M9 21h6"/>
      </svg>;
    case 'review':   // bookmark / journal — single shape, clearer
      return <svg {...props}>
        <path d="M6 4h12v17l-6-3.5L6 21V4z" {...soft}/>
        <path d="M9.5 9h5"/>
      </svg>;
    case 'social':   // two people — refined silhouettes
      return <svg {...props}>
        <circle cx="9" cy="8.5" r="3.2" {...soft}/>
        <path d="M3.5 19c0-3 2.5-5.2 5.5-5.2s5.5 2.2 5.5 5.2"/>
        <circle cx="16.5" cy="9.5" r="2.6" fill={color} fillOpacity="0.18" stroke={color}/>
        <path d="M14 14.6c2.6-.4 5.2 1 6.5 3.4"/>
      </svg>;
    case 'settings': // gear — clean 6-tooth, properly proportioned
      return <svg {...props}>
        <circle cx="12" cy="12" r="3" {...soft}/>
        <path d="M12 2.5v2.4M12 19.1v2.4M21.5 12h-2.4M4.9 12H2.5M18.7 5.3l-1.7 1.7M7 17l-1.7 1.7M18.7 18.7L17 17M7 7L5.3 5.3"/>
      </svg>;
    default: return null;
  }
};

const BottomNav = ({ active, onNavigate }) => {
  const items = [
    { id:'train',    label:'Train',    target:'modes'    },
    { id:'review',   label:'Review',   target:'review'   },
    { id:'social',   label:'Social',   target:'social'   },
    { id:'settings', label:'Settings', target:'settings' },
  ];
  const TINT = '#3378F5';
  return (
    <div style={{
      position:'absolute',left:14,right:14,bottom:14,
      background:'rgba(255,255,255,0.92)',
      backdropFilter:'blur(20px)',WebkitBackdropFilter:'blur(20px)',
      borderRadius:26,border:'1px solid rgba(15,23,42,0.06)',
      padding:'10px 8px',display:'flex',gap:2,
      boxShadow:'0 1px 0 rgba(15,23,42,0.04), 0 14px 36px -10px rgba(15,23,42,0.18)',
      zIndex:10,
    }}>
      {items.map(it => {
        const sel = active === it.id;
        const color = sel ? TINT : '#7C8594';
        return (
          <Pressable key={it.id} onClick={() => onNavigate(it.target)} style={{
            flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',
            gap:3,minWidth:0,padding:'6px 4px',borderRadius:18,
            background: sel ? `${TINT}10` : 'transparent',
            transition:'background 220ms ease',
          }}>
            <TabGlyph name={it.id} color={color} size={22}/>
            <div style={{
              fontFamily:"'Manrope',system-ui",fontSize:10.5,fontWeight: sel ? 800 : 600,
              letterSpacing:0.2,color:color,
            }}>{it.label}</div>
          </Pressable>
        );
      })}
    </div>
  );
};

const styles = {
  screen: {
    position:'relative',width:'100%',height:'100%',
    background:'#F2F2F7',
    fontFamily:"-apple-system, 'SF Pro Text', system-ui",
    color:'#212633',overflow:'hidden',
  },
};

Object.assign(window, { HomeScreen, BottomNav, homeStyles: styles });
