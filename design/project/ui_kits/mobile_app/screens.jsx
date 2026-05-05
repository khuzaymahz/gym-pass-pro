// GymPass — individual screen components. Imports globals from common.jsx.

// ─── 1. LOGIN ───
function LoginScreen() {
  return (
    <Screen>
      <div style={{ padding: '40px 24px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Wordmark size={26}/>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 24 }}>
          <Overline>● ONE SUB · EVERY GYM</Overline>
          <div>
            <Display size={56}>ONE PASS.</Display>
            <Display size={56}>EVERY <SerifAccent size={56}>gym</SerifAccent>.</Display>
          </div>
          <div style={{ color: GP.ink3, fontSize: 15, lineHeight: 1.5, maxWidth: 280 }}>
            Browse 120+ clubs across Jordan. Pick a tier. Check in with a scan.
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth>GET STARTED →</PillButton>
          <PillButton fullWidth>I already have an account</PillButton>
          <div style={{ textAlign: 'center', fontFamily: GP.fMono, fontSize: 10, color: GP.ink4, letterSpacing: '0.14em', marginTop: 10 }}>
            ◆ MADE IN AMMAN · ع EN
          </div>
        </div>
      </div>
    </Screen>
  );
}

// ─── 2. HOME ───
function HomeScreen() {
  const venue = (name, cat, dist, state, color) => (
    <div style={{ display: 'flex', gap: 12, padding: 14, background: GP.bg2, border: `1px solid ${GP.border}`, borderRadius: 16, alignItems: 'center' }}>
      <div style={{ width: 54, height: 54, borderRadius: 12, background: `linear-gradient(135deg, ${color}22, #0A0B0A)`, border: `1px solid ${color}33`, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ fontFamily: GP.fMono, fontSize: 9, color: color, letterSpacing: '0.1em' }}>{cat.slice(0,3)}</div>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: GP.fMono, fontSize: 9, color: color, letterSpacing: '0.14em', textTransform: 'uppercase' }}>{cat}</div>
        <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 17, letterSpacing: '-0.02em', color: GP.ink, textTransform: 'uppercase', marginTop: 2 }}>{name}</div>
        <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3, marginTop: 4, display: 'flex', gap: 6 }}>
          <span>{dist}</span>·<span style={{ color: state === 'OPEN' ? '#30D158' : state === 'BUSY' ? '#FFE36B' : '#FF6B62' }}>{state}</span>
        </div>
      </div>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={GP.ink3} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.chev}/></svg>
    </div>
  );
  return (
    <Screen>
      <div style={{ padding: '10px 20px 140px', overflowY: 'auto', height: '100%' }}>
        {/* top nav */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <Wordmark size={22}/>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GP.ink }}><SvgSearch/></div>
            <div style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GP.ink, position: 'relative' }}><SvgBell/><div style={{ position: 'absolute', top: 7, right: 9, width: 8, height: 8, borderRadius: 100, background: GP.lime, boxShadow: `0 0 6px ${GP.lime}` }}/></div>
          </div>
        </div>

        {/* greeting */}
        <Overline>● MONDAY · 18:42</Overline>
        <div style={{ marginTop: 8 }}>
          <Display size={38}>MOHAMMAD,</Display>
          <Display size={38}><SerifAccent size={38}>let's train.</SerifAccent></Display>
        </div>

        {/* active plan hero */}
        <div style={{ marginTop: 22, padding: 18, borderRadius: 20, background: GP.bg2, border: `1px solid ${GP.border}`, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -40, right: -40, width: 180, height: 180, borderRadius: 100, background: 'radial-gradient(circle, rgba(187,251,70,0.18), transparent 65%)' }}/>
          <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <Overline>● ACTIVE PLAN</Overline>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 32, letterSpacing: '-0.035em', color: GP.ink, marginTop: 6 }}>GOLD</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 4 }}>23 / 30 VISITS · 7 DAYS LEFT</div>
            </div>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 10px', borderRadius: 5, background: 'rgba(255,215,0,0.12)', color: '#FFE36B', fontFamily: GP.fMono, fontSize: 10, fontWeight: 600, letterSpacing: '0.12em', border: '1px solid rgba(255,215,0,0.3)' }}>◆ GOLD</div>
          </div>
          {/* progress bar */}
          <div style={{ marginTop: 16, height: 6, borderRadius: 100, background: GP.bg3, overflow: 'hidden' }}>
            <div style={{ width: '76%', height: '100%', background: `linear-gradient(90deg, ${GP.lime}, ${GP.lime2})`, boxShadow: `0 0 10px ${GP.lime}`, borderRadius: 100 }}/>
          </div>
        </div>

        {/* near you */}
        <div style={{ marginTop: 28, display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <Overline color={GP.ink3}>● NEAR YOU</Overline>
          <span style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.lime, letterSpacing: '0.14em' }}>SEE ALL →</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {venue('Iron Forge', 'GYM', '0.4 KM', 'OPEN', '#BBFB46')}
          {venue('Bedford Yoga', 'YOGA', '0.8 KM', 'OPEN', '#BF5AF2')}
          {venue('Fortis Boxing', 'MARTIAL', '1.2 KM', 'BUSY', '#FF453A')}
        </div>
      </div>
      <TabBar active="home"/>
    </Screen>
  );
}

// ─── 3. QR SCAN ───
function QRScreen() {
  return (
    <Screen>
      <div style={{ padding: '10px 20px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GP.ink }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.back}/></svg>
          </div>
          <Overline color={GP.ink3}>● CHECK IN</Overline>
          <div style={{ width: 38 }}/>
        </div>

        <div style={{ marginTop: 28 }}>
          <Display size={44}>SCAN <SerifAccent size={44}>& go.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>Point at the gym's QR code.</div>
        </div>

        {/* viewport */}
        <div style={{ position: 'relative', marginTop: 32, width: '100%', aspectRatio: '1', borderRadius: 24, overflow: 'hidden', background: '#05070555', border: `1px solid ${GP.border2}` }}>
          {/* camera texture */}
          <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 50%, #1a2010 0%, #05070500 70%)' }}/>
          {/* corners */}
          {[[0,0,0,0], [0,0,0,1], [0,0,1,0], [0,0,1,1]].map((_, i) => {
            const t = i < 2 ? 20 : 'auto'; const b = i >= 2 ? 20 : 'auto';
            const l = i % 2 === 0 ? 20 : 'auto'; const r = i % 2 === 1 ? 20 : 'auto';
            return (
              <div key={i} style={{
                position: 'absolute', top: t, bottom: b, left: l, right: r,
                width: 36, height: 36,
                borderTop: i < 2 ? `3px solid ${GP.lime}` : 'none',
                borderBottom: i >= 2 ? `3px solid ${GP.lime}` : 'none',
                borderLeft: i % 2 === 0 ? `3px solid ${GP.lime}` : 'none',
                borderRight: i % 2 === 1 ? `3px solid ${GP.lime}` : 'none',
                borderTopLeftRadius: i === 0 ? 12 : 0,
                borderTopRightRadius: i === 1 ? 12 : 0,
                borderBottomLeftRadius: i === 2 ? 12 : 0,
                borderBottomRightRadius: i === 3 ? 12 : 0,
                boxShadow: `0 0 12px ${GP.lime}66`,
              }}/>
            );
          })}
          {/* scanline */}
          <div style={{ position: 'absolute', left: 24, right: 24, top: '50%', height: 2, background: `linear-gradient(90deg, transparent, ${GP.lime}, transparent)`, boxShadow: `0 0 14px ${GP.lime}` }}/>
        </div>

        <div style={{ textAlign: 'center', marginTop: 18, fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, letterSpacing: '0.18em' }}>
          ALIGN QR WITHIN THE FRAME
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ padding: '0 0 40px' }}>
          <PillButton fullWidth>Enter code manually</PillButton>
        </div>
      </div>
    </Screen>
  );
}

// ─── 4. PLANS / TIERS ───
function PlansScreen() {
  const tier = (name, glyph, price, visits, features, color, selected) => (
    <div style={{
      padding: 18, borderRadius: 20,
      background: selected ? GP.bg2 : GP.bg,
      border: `1px solid ${selected ? color + '66' : GP.border}`,
      position: 'relative', overflow: 'hidden',
    }}>
      {selected && <div style={{ position: 'absolute', top: -30, right: -30, width: 140, height: 140, borderRadius: 100, background: `radial-gradient(circle, ${color}22, transparent 65%)` }}/>}
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 9px', borderRadius: 5, background: `${color}14`, color, fontFamily: GP.fMono, fontSize: 10, fontWeight: 600, letterSpacing: '0.12em', border: `1px solid ${color}44` }}>{glyph} {name.toUpperCase()}</div>
          <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 32, letterSpacing: '-0.035em', color: GP.ink, marginTop: 10 }}>{visits} VISITS</div>
          <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 2 }}>per month</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: GP.ink, letterSpacing: '-0.03em' }}>{price}</div>
          <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3 }}>JOD / MO</div>
        </div>
      </div>
      <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 6 }}>
        {features.map((f, i) => (
          <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13, color: GP.ink2 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.check}/></svg>
            {f}
          </div>
        ))}
      </div>
    </div>
  );
  return (
    <Screen>
      <div style={{ padding: '10px 20px 110px', overflowY: 'auto', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
          <div style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={GP.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.back}/></svg>
          </div>
          <Overline color={GP.ink3}>● STEP 1 OF 3</Overline>
          <div style={{ width: 38 }}/>
        </div>
        <div style={{ marginTop: 14 }}>
          <Display size={44}>PICK A <SerifAccent size={44}>pass.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>More gyms, more visits, more everything.</div>
        </div>
        <div style={{ marginTop: 22, display: 'flex', flexDirection: 'column', gap: 12 }}>
          {tier('Silver', '◇', '25', 12, ['50+ basic gyms', 'Business hours'], '#C0C0C0', false)}
          {tier('Gold', '◆', '45', 30, ['120+ gyms', 'Extended hours', '5 guest passes'], '#FFD60A', true)}
          {tier('Platinum', '◈', '75', 60, ['All 220 clubs', '24/7 access', 'Classes included'], '#E0E6FF', false)}
        </div>
      </div>
      <div style={{ position: 'absolute', bottom: 34, left: 20, right: 20 }}>
        <PillButton primary fullWidth>CONTINUE WITH GOLD →</PillButton>
      </div>
    </Screen>
  );
}

// ─── 5. SUCCESS ───
function SuccessScreen() {
  return (
    <Screen>
      <div style={{ padding: 24, display: 'flex', flexDirection: 'column', height: '100%', alignItems: 'center', justifyContent: 'center' }}>
        {/* concentric rings */}
        <div style={{ position: 'relative', width: 180, height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {[0, 1, 2].map(i => (
            <div key={i} style={{ position: 'absolute', inset: -i*22, borderRadius: 100, border: `1.5px solid ${GP.lime}${['ff','66','22'][i]}`, boxShadow: i === 0 ? `0 0 40px ${GP.lime}66` : 'none' }}/>
          ))}
          <div style={{ width: 120, height: 120, borderRadius: 100, background: `linear-gradient(180deg, ${GP.lime2}, ${GP.lime})`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 60px ${GP.lime}88` }}>
            <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="#0A0B0A" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.check}/></svg>
          </div>
        </div>
        <div style={{ textAlign: 'center', marginTop: 40 }}>
          <Display size={48}>YOU'RE IN.</Display>
          <Display size={40}><SerifAccent size={44}>welcome to</SerifAccent></Display>
          <Display size={48} color="#FFE36B">◆ GOLD.</Display>
        </div>
        <div style={{ color: GP.ink3, fontSize: 14, marginTop: 18, textAlign: 'center', maxWidth: 280 }}>
          30 visits/month · 120+ clubs · renews Nov 14
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth>FIND YOUR FIRST GYM →</PillButton>
          <PillButton fullWidth>View receipt</PillButton>
        </div>
      </div>
    </Screen>
  );
}

// ─── 6. PROFILE ───
function ProfileScreen() {
  return (
    <Screen>
      <div style={{ padding: '10px 20px 120px', overflowY: 'auto', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
          <Overline color={GP.ink3}>● YOU</Overline>
          <div style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GP.ink }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.01a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.01a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
          </div>
        </div>

        {/* avatar + name */}
        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          <div style={{ width: 72, height: 72, borderRadius: 100, background: `linear-gradient(135deg, ${GP.lime2}, ${GP.lime})`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: '#0A0B0A', letterSpacing: '-0.04em' }}>MA</div>
          <div>
            <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 24, color: GP.ink, letterSpacing: '-0.03em', textTransform: 'uppercase' }}>Mohammad A.</div>
            <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 2 }}>◆ GOLD · SINCE AUG 2024</div>
          </div>
        </div>

        {/* stats ring */}
        <div style={{ marginTop: 22, padding: 18, borderRadius: 20, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', gap: 18, alignItems: 'center' }}>
          <div style={{ position: 'relative', width: 100, height: 100 }}>
            <svg width="100" height="100" viewBox="0 0 100 100" style={{ transform: 'rotate(-90deg)' }}>
              <circle cx="50" cy="50" r="42" fill="none" stroke={GP.bg3} strokeWidth="8"/>
              <circle cx="50" cy="50" r="42" fill="none" stroke={GP.lime} strokeWidth="8" strokeLinecap="round" strokeDasharray="264" strokeDashoffset="66" style={{ filter: `drop-shadow(0 0 6px ${GP.lime}aa)` }}/>
            </svg>
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: GP.ink, letterSpacing: '-0.04em', lineHeight: 1 }}>23</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 9, color: GP.ink3, letterSpacing: '0.14em' }}>/ 30</div>
            </div>
          </div>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[['STREAK', '14 DAYS', GP.lime], ['THIS MO', '23 VISITS', GP.ink], ['NEXT', 'DIAMOND', '#9EE7FF']].map(([k,v,c]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: GP.fMono, fontSize: 11 }}>
                <span style={{ color: GP.ink3, letterSpacing: '0.1em' }}>{k}</span>
                <span style={{ color: c, fontWeight: 600 }}>{v}</span>
              </div>
            ))}
          </div>
        </div>

        {/* menu rows */}
        <div style={{ marginTop: 18, borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}`, overflow: 'hidden' }}>
          {[['Subscription', '◆ Gold'], ['Payment methods', '•••• 4421'], ['Guest passes', '2 left'], ['Visit history', '23'], ['Language', 'EN · ع']].map(([k, v], i, a) => (
            <div key={k} style={{ display: 'flex', padding: '14px 16px', alignItems: 'center', justifyContent: 'space-between', borderBottom: i < a.length-1 ? `1px solid ${GP.border}` : 'none' }}>
              <div style={{ fontSize: 15, color: GP.ink }}>{k}</div>
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <span style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3 }}>{v}</span>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={GP.ink4} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.chev}/></svg>
              </div>
            </div>
          ))}
        </div>
      </div>
      <TabBar active="profile"/>
    </Screen>
  );
}

Object.assign(window, { LoginScreen, HomeScreen, QRScreen, PlansScreen, SuccessScreen, ProfileScreen });
