// Main app: Home, Gyms browse, Gym detail, Scan, CheckInSuccess, Profile, MySubscription, Settings, Notifications

// ─── HOME ───
function HomeScreen() {
  const { go, state, update } = useRoute();
  const sub = state.subscription;
  const t = sub ? TIERS[sub.tier] : null;
  const visitsLeft = sub ? sub.visitsTotal - sub.visitsUsed : 0;
  const pct = sub ? (sub.visitsUsed / sub.visitsTotal) * 100 : 0;
  return (
    <Phone>
      <div style={{ padding: '10px 20px 140px', overflowY: 'auto', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 22 }}>
          <Wordmark size={22}/>
          <div style={{ display: 'flex', gap: 8 }}>
            <IconBtn icon={<SvgSearch/>} onClick={() => go('gyms')}/>
            <IconBtn icon={<SvgBell/>} badge onClick={() => go('notifications')}/>
          </div>
        </div>

        <Mono size={10} color={GP.ink3} tracking={0.2}>● MONDAY · 18:42</Mono>
        <div style={{ marginTop: 6 }}>
          <Display size={36}>{(state.auth.name || 'Mohammad').split(' ')[0].toUpperCase()},</Display>
          <Display size={36}><SerifAccent size={36}>let's train.</SerifAccent></Display>
        </div>

        {sub ? (
          <button onClick={() => go('mySubscription')} style={{ all: 'unset', cursor: 'pointer', display: 'block', width: '100%' }}>
            <div style={{ marginTop: 22, padding: 18, borderRadius: 20, background: GP.bg2, border: `1px solid ${GP.border}`, position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', top: -40, right: -40, width: 180, height: 180, borderRadius: 100, background: `radial-gradient(circle, ${t.color}22, transparent 65%)` }}/>
              <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <Overline>● ACTIVE PLAN</Overline>
                  <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 32, letterSpacing: '-0.035em', color: GP.ink, marginTop: 6 }}>{t.name.toUpperCase()}</div>
                  <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 4, letterSpacing: '0.1em' }}>{sub.visitsUsed} / {sub.visitsTotal} VISITS · 7 DAYS LEFT</div>
                </div>
                <TierChip tier={sub.tier}/>
              </div>
              <div style={{ marginTop: 16, height: 6, borderRadius: 100, background: GP.bg3, overflow: 'hidden' }}>
                <div style={{ width: `${pct}%`, height: '100%', background: `linear-gradient(90deg, ${GP.lime}, ${GP.lime2})`, boxShadow: `0 0 10px ${GP.lime}`, borderRadius: 100 }}/>
              </div>
              <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Mono size={9} color={GP.ink4} tracking={0.14}>{visitsLeft} LEFT THIS CYCLE</Mono>
                <Mono size={9} color={GP.lime} tracking={0.14}>MANAGE →</Mono>
              </div>
            </div>
          </button>
        ) : (
          <div style={{ marginTop: 22, padding: 18, borderRadius: 20, background: GP.bg2, border: `1px dashed ${GP.border2}` }}>
            <Overline color={GP.ink3}>● NO ACTIVE PLAN</Overline>
            <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 24, color: GP.ink, marginTop: 8, letterSpacing: '-0.03em' }}>START TRAINING</div>
            <div style={{ color: GP.ink3, fontSize: 13, marginTop: 4 }}>Pick a tier to unlock your first gym.</div>
            <div style={{ marginTop: 12 }}>
              <PillButton primary onClick={() => go('plans')}>PICK A PASS →</PillButton>
            </div>
          </div>
        )}

        {/* Near you */}
        <div style={{ marginTop: 26, display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <Overline color={GP.ink3}>● NEAR YOU</Overline>
          <button onClick={() => go('gyms')} style={{ all: 'unset', cursor: 'pointer', fontFamily: GP.fMono, fontSize: 10, color: GP.lime, letterSpacing: '0.14em' }}>SEE ALL →</button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {GYMS.slice(0, 3).map(g => <GymRow key={g.id} gym={g} onClick={() => go('gymDetail', { id: g.id })}/>)}
        </div>

        {/* Category picker */}
        <div style={{ marginTop: 24 }}>
          <Overline color={GP.ink3}>● BROWSE BY CATEGORY</Overline>
          <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
            {[['GYM', GP.lime], ['CROSS', '#30D158'], ['MARTIAL', '#FF453A'], ['YOGA', '#BF5AF2']].map(([k, c]) => (
              <button key={k} onClick={() => { update({ filter: k }); go('gyms'); }} style={{ all: 'unset', cursor: 'pointer', padding: 12, borderRadius: 14, background: `linear-gradient(135deg, ${c}14, transparent)`, border: `1px solid ${c}33`, textAlign: 'center' }}>
                <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 13, color: c, letterSpacing: '-0.02em' }}>{k}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
      <TabBar active="home" onTab={k => go(k)} onCenter={() => go('scan')}/>
    </Phone>
  );
}
function GymRow({ gym, onClick }) {
  return (
    <button onClick={onClick} style={{ all: 'unset', cursor: 'pointer', display: 'flex', gap: 12, padding: 14, background: GP.bg2, border: `1px solid ${GP.border}`, borderRadius: 16, alignItems: 'center' }}>
      <GymTile gym={gym}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <Mono size={9} color={gym.color} tracking={0.14}>{gym.cat}</Mono>
        <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 17, letterSpacing: '-0.02em', color: GP.ink, textTransform: 'uppercase', marginTop: 2 }}>{gym.name}</div>
        <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3, marginTop: 4, display: 'flex', gap: 6, letterSpacing: '0.08em' }}>
          <span>{gym.area}</span>·<span>{gym.dist.toUpperCase()}</span>·<span style={{ color: gym.state === 'OPEN' ? GP.green : gym.state === 'BUSY' ? '#FFE36B' : '#FF6B62' }}>{gym.state}</span>
        </div>
      </div>
      <I path="chev" size={16} color={GP.ink3}/>
    </button>
  );
}

// ─── GYMS BROWSE ───
function GymsScreen() {
  const { go, state, update } = useRoute();
  const [filter, setFilter] = React.useState(state.filter || 'ALL');
  const [q, setQ] = React.useState('');
  const list = GYMS.filter(g => (filter === 'ALL' || g.cat.startsWith(filter.slice(0,5))) && (q === '' || g.name.toLowerCase().includes(q.toLowerCase())));
  return (
    <Phone>
      <div style={{ padding: '10px 20px 120px', overflowY: 'auto', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
          <BackBtn onClick={() => go('home')}/>
          <Overline color={GP.ink3}>● {GYMS.length} CLUBS</Overline>
          <IconBtn icon={<I path="filter" size={18}/>}/>
        </div>

        <Display size={36}>EVERY <SerifAccent size={36}>club.</SerifAccent></Display>

        {/* Search */}
        <div style={{ marginTop: 14, display: 'flex', gap: 10, alignItems: 'center', padding: '12px 16px', background: GP.bg2, border: `1px solid ${GP.border}`, borderRadius: 28 }}>
          <SvgSearch size={18}/>
          <input value={q} onChange={e => setQ(e.target.value)} placeholder="Search name, area, category" style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: GP.ink, fontSize: 14 }}/>
        </div>

        {/* Filter pills */}
        <div style={{ marginTop: 14, display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
          {['ALL','GYM','CROSSFIT','MARTIAL','YOGA'].map(f => {
            const on = filter === f;
            return (
              <button key={f} onClick={() => setFilter(f)} style={{ all: 'unset', cursor: 'pointer', padding: '8px 14px', borderRadius: 100, fontFamily: GP.fMono, fontSize: 10, letterSpacing: '0.14em', color: on ? '#0A0B0A' : GP.ink2, background: on ? GP.lime : GP.bg2, border: `1px solid ${on ? GP.lime : GP.border2}`, flexShrink: 0 }}>
                {f}
              </button>
            );
          })}
        </div>

        {/* Map preview */}
        <div style={{ marginTop: 14, height: 150, borderRadius: 20, overflow: 'hidden', position: 'relative', background: 'linear-gradient(135deg, #0E1210, #151918)', border: `1px solid ${GP.border}` }}>
          <svg width="100%" height="100%" viewBox="0 0 350 150" preserveAspectRatio="none">
            <defs>
              <pattern id="grid" width="28" height="28" patternUnits="userSpaceOnUse"><path d="M 28 0 L 0 0 0 28" fill="none" stroke="rgba(255,255,255,0.04)" strokeWidth="1"/></pattern>
            </defs>
            <rect width="350" height="150" fill="url(#grid)"/>
            {/* roads */}
            <path d="M0 90 Q120 60 260 100 T 350 130" stroke="rgba(187,251,70,0.25)" strokeWidth="2" fill="none"/>
            <path d="M80 0 Q100 60 140 80 T 240 150" stroke="rgba(255,255,255,0.08)" strokeWidth="1.5" fill="none"/>
            <path d="M200 0 L 180 150" stroke="rgba(255,255,255,0.08)" strokeWidth="1.5" fill="none"/>
          </svg>
          {/* pins */}
          {GYMS.slice(0,4).map((g, i) => {
            const pos = [[70,60],[160,40],[200,95],[280,70]][i];
            return (
              <div key={g.id} style={{ position: 'absolute', left: pos[0], top: pos[1], display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{ width: 26, height: 26, borderRadius: 100, background: g.color, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 12px ${g.color}aa`, border: '2px solid #0A0B0A' }}>
                  <I path="pin" size={14} color="#0A0B0A" stroke={2.5}/>
                </div>
              </div>
            );
          })}
          <div style={{ position: 'absolute', top: 10, left: 12, padding: '4px 8px', borderRadius: 5, background: 'rgba(10,11,10,0.8)', backdropFilter: 'blur(8px)', fontFamily: GP.fMono, fontSize: 9, color: GP.lime, letterSpacing: '0.14em' }}>● LIVE · AMMAN</div>
          <div style={{ position: 'absolute', bottom: 10, right: 12, padding: '4px 10px', borderRadius: 5, background: 'rgba(10,11,10,0.8)', fontFamily: GP.fMono, fontSize: 9, color: GP.ink2, letterSpacing: '0.14em' }}>VIEW MAP →</div>
        </div>

        {/* List */}
        <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {list.map(g => <GymRow key={g.id} gym={g} onClick={() => go('gymDetail', { id: g.id })}/>)}
          {list.length === 0 && <div style={{ color: GP.ink3, textAlign: 'center', padding: 24, fontSize: 13 }}>No gyms match.</div>}
        </div>
      </div>
      <TabBar active="gyms" onTab={k => go(k)} onCenter={() => go('scan')}/>
    </Phone>
  );
}

// ─── GYM DETAIL ───
function GymDetailScreen() {
  const { go, route, state, update } = useRoute();
  const gym = GYMS.find(g => g.id === route.params.id) || GYMS[0];
  const sub = state.subscription;
  const userTier = sub ? TIERS[sub.tier].rank : -1;
  const needed = TIERS[gym.minTier].rank;
  const locked = !sub || userTier < needed;
  const [liked, setLiked] = React.useState(false);
  return (
    <Phone hideStatusBar>
      <div style={{ overflowY: 'auto', height: '100%', paddingBottom: 130 }}>
        {/* Hero (full-bleed, extends behind status bar) */}
        <div style={{ position: 'relative', height: 320, background: `linear-gradient(135deg, ${gym.color}30, #0A0B0A 72%)`, overflow: 'hidden' }}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0.22 }}>
            <svg width="240" height="240" viewBox="0 0 24 24" fill="none" stroke={gym.color} strokeWidth="1.2"><path d="M6 6l12 12M18 6L6 18M2 12h4M18 12h4M12 2v4M12 18v4"/><circle cx="12" cy="12" r="3.2"/></svg>
          </div>
          {/* bottom scrim */}
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, transparent 40%, rgba(10,11,10,0.96))' }}/>
          {/* top scrim so status bar icons read */}
          <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 80, background: 'linear-gradient(to bottom, rgba(10,11,10,0.55), transparent)' }}/>

          {/* Mini status bar (duplicated because Phone's is suppressed here for full-bleed) */}
          <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 28px 0', fontFamily: '-apple-system, system-ui', fontSize: 15, fontWeight: 600, color: GP.ink, zIndex: 30 }}>
            <span>9:41</span>
            <span style={{ fontSize: 13, display: 'flex', gap: 6, alignItems: 'center' }}>
              <svg width="17" height="11" viewBox="0 0 17 11" fill="currentColor"><rect x="0" y="7" width="3" height="4" rx="0.5"/><rect x="4.5" y="5" width="3" height="6" rx="0.5"/><rect x="9" y="2.5" width="3" height="8.5" rx="0.5"/><rect x="13.5" y="0" width="3" height="11" rx="0.5"/></svg>
              <svg width="24" height="11" viewBox="0 0 24 11" fill="none"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke="currentColor" opacity="0.4"/><rect x="2" y="2" width="17" height="7" rx="1" fill="currentColor"/><rect x="21" y="3.5" width="2" height="4" rx="0.5" fill="currentColor" opacity="0.4"/></svg>
            </span>
          </div>

          <div style={{ position: 'absolute', top: 60, left: 20, right: 20, display: 'flex', justifyContent: 'space-between', zIndex: 25 }}>
            <BackBtn onClick={() => go('gyms')}/>
            <IconBtn icon={<I path="heart" size={18} color={liked ? GP.red : GP.ink}/>} onClick={() => setLiked(l => !l)}/>
          </div>

          <div style={{ position: 'absolute', bottom: 20, left: 20, right: 20 }}>
            <Mono size={10} color={gym.color} tracking={0.18}>● {gym.cat} · {gym.area.toUpperCase()}</Mono>
            <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 34, color: GP.ink, marginTop: 6, letterSpacing: '-0.035em', textTransform: 'uppercase' }}>{gym.name}</div>
            <div style={{ display: 'flex', gap: 12, marginTop: 8, alignItems: 'center' }}>
              <span style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink2, display: 'flex', gap: 5, alignItems: 'center' }}>
                <I path="star" size={12} color={GP.yellow}/> {gym.rating} <span style={{ color: GP.ink4 }}>({gym.reviews})</span>
              </span>
              <span style={{ fontFamily: GP.fMono, fontSize: 11, color: gym.state === 'OPEN' ? GP.green : gym.state === 'BUSY' ? '#FFE36B' : GP.red, letterSpacing: '0.12em' }}>● {gym.state}</span>
              <span style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3 }}>{gym.dist}</span>
            </div>
          </div>
        </div>

        {/* Access banner */}
        <div style={{ margin: '14px 20px 0', padding: 14, borderRadius: 16, background: locked ? 'rgba(255, 69, 58, 0.08)' : 'rgba(187,251,70,0.08)', border: `1px solid ${locked ? 'rgba(255,69,58,0.3)' : 'rgba(187,251,70,0.3)'}` }}>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <I path={locked ? 'lock' : 'check'} size={18} color={locked ? GP.red : GP.lime}/>
            <div style={{ flex: 1 }}>
              <div style={{ color: locked ? GP.red : GP.lime, fontFamily: GP.fMono, fontSize: 10, letterSpacing: '0.14em' }}>
                {locked ? `REQUIRES ${TIERS[gym.minTier].name.toUpperCase()}+` : 'INCLUDED IN YOUR PLAN'}
              </div>
              <div style={{ color: GP.ink2, fontSize: 12, marginTop: 2 }}>
                {locked ? 'Upgrade to unlock this club.' : 'Scan QR at the door to check in.'}
              </div>
            </div>
            <TierChip tier={gym.minTier}/>
          </div>
        </div>

        {/* Details */}
        <div style={{ padding: 20 }}>
          <Overline color={GP.ink3}>● HOURS</Overline>
          <div style={{ marginTop: 6, fontFamily: GP.fDisplay, fontStyle: 'italic', fontWeight: 900, fontSize: 22, color: GP.ink, letterSpacing: '-0.03em' }}>{gym.hours}</div>

          <div style={{ marginTop: 22 }}>
            <Overline color={GP.ink3}>● AMENITIES</Overline>
            <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
              {gym.amenities.map(a => (
                <div key={a} style={{ padding: '10px 6px', borderRadius: 12, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, color: GP.ink2 }}>
                  <div style={{ fontSize: 16 }}>●</div>
                  <Mono size={9} color={GP.ink2} tracking={0.12}>{a.toUpperCase()}</Mono>
                </div>
              ))}
            </div>
          </div>

          <div style={{ marginTop: 22 }}>
            <Overline color={GP.ink3}>● ABOUT</Overline>
            <div style={{ marginTop: 8, fontSize: 13, color: GP.ink2, lineHeight: 1.6 }}>
              A {gym.cat.toLowerCase()} club in {gym.area}. Pro-grade equipment, open schedule, friendly staff. Part of the GymPass network since 2024.
            </div>
          </div>

          <div style={{ marginTop: 22 }}>
            <Overline color={GP.ink3}>● LOCATION</Overline>
            <div style={{ marginTop: 8, height: 140, borderRadius: 16, overflow: 'hidden', position: 'relative', background: 'linear-gradient(135deg, #0E1210, #151918)', border: `1px solid ${GP.border}` }}>
              <svg width="100%" height="100%" viewBox="0 0 350 140" preserveAspectRatio="none">
                <path d="M0 70 Q100 40 200 80 T 350 100" stroke="rgba(187,251,70,0.25)" strokeWidth="2" fill="none"/>
                <path d="M130 0 Q140 70 180 140" stroke="rgba(255,255,255,0.08)" strokeWidth="1.5" fill="none"/>
              </svg>
              <div style={{ position: 'absolute', left: '48%', top: '44%', width: 30, height: 30, borderRadius: 100, background: gym.color, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 16px ${gym.color}`, border: '2px solid #0A0B0A' }}>
                <I path="pin" size={16} color="#0A0B0A" stroke={2.5}/>
              </div>
              <div style={{ position: 'absolute', bottom: 10, left: 12, fontFamily: GP.fMono, fontSize: 10, color: GP.ink2, letterSpacing: '0.12em' }}>{gym.area.toUpperCase()} · {gym.dist.toUpperCase()} FROM YOU</div>
            </div>
          </div>
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 24, left: 20, right: 20 }}>
        {locked ? (
          <PillButton primary fullWidth onClick={() => go('plans')}>UPGRADE TO {TIERS[gym.minTier].name.toUpperCase()} →</PillButton>
        ) : (
          <PillButton primary fullWidth onClick={() => go('scan')}>CHECK IN HERE →</PillButton>
        )}
      </div>
    </Phone>
  );
}

// ─── SCAN ───
function ScanScreen() {
  const { go, state, update } = useRoute();
  const [scanning, setScanning] = React.useState(true);
  React.useEffect(() => {
    if (!scanning) return;
    const t = setTimeout(() => {
      // Auto-complete scan after a moment for demo
      const sub = state.subscription;
      if (!sub) return;
      update(s => ({
        subscription: { ...s.subscription, visitsUsed: Math.min(s.subscription.visitsTotal, s.subscription.visitsUsed + 1) },
        lastCheckIn: { gymId: 'iron-forge', at: Date.now() },
      }));
      go('checkInSuccess', { gymId: 'iron-forge' });
    }, 3200);
    return () => clearTimeout(t);
  }, [scanning]);

  return (
    <Phone>
      <div style={{ padding: '10px 20px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <BackBtn onClick={() => go('home')}/>
          <Overline color={GP.ink3}>● CHECK IN</Overline>
          <div style={{ width: 38 }}/>
        </div>

        <div style={{ marginTop: 20 }}>
          <Display size={44}>SCAN <SerifAccent size={44}>& go.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>Point at the gym's QR code.</div>
        </div>

        <div style={{ position: 'relative', marginTop: 28, width: '100%', aspectRatio: '1', borderRadius: 24, overflow: 'hidden', background: '#05070555', border: `1px solid ${GP.border2}` }}>
          <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 50%, #1a2010 0%, #05070500 70%)' }}/>
          {[0,1,2,3].map(i => {
            const t = i < 2 ? 20 : 'auto'; const b = i >= 2 ? 20 : 'auto';
            const l = i % 2 === 0 ? 20 : 'auto'; const r = i % 2 === 1 ? 20 : 'auto';
            return <div key={i} style={{
              position: 'absolute', top: t, bottom: b, left: l, right: r, width: 36, height: 36,
              borderTop: i < 2 ? `3px solid ${GP.lime}` : 'none',
              borderBottom: i >= 2 ? `3px solid ${GP.lime}` : 'none',
              borderLeft: i % 2 === 0 ? `3px solid ${GP.lime}` : 'none',
              borderRight: i % 2 === 1 ? `3px solid ${GP.lime}` : 'none',
              borderTopLeftRadius: i === 0 ? 12 : 0,
              borderTopRightRadius: i === 1 ? 12 : 0,
              borderBottomLeftRadius: i === 2 ? 12 : 0,
              borderBottomRightRadius: i === 3 ? 12 : 0,
              boxShadow: `0 0 12px ${GP.lime}66`,
            }}/>;
          })}
          {/* Scanline */}
          <div style={{ position: 'absolute', left: 24, right: 24, top: 20, bottom: 20, overflow: 'hidden' }}>
            <div style={{ position: 'absolute', left: 0, right: 0, height: 2, background: `linear-gradient(90deg, transparent, ${GP.lime}, transparent)`, boxShadow: `0 0 14px ${GP.lime}`, animation: 'gpScan 2.5s ease-in-out infinite' }}/>
          </div>
          {/* Dot QR hint */}
          <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', opacity: 0.12 }}>
            <div style={{ width: 140, height: 140, display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 3 }}>
              {Array.from({ length: 64 }).map((_, i) => {
                const on = (i * 13 % 5) > 2 || i === 0 || i === 7 || i === 56 || i === 63;
                return <div key={i} style={{ background: on ? GP.ink : 'transparent', borderRadius: 2 }}/>;
              })}
            </div>
          </div>
        </div>

        <div style={{ textAlign: 'center', marginTop: 18, fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, letterSpacing: '0.18em' }}>
          ALIGN QR WITHIN THE FRAME
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ padding: '0 0 40px' }}>
          <PillButton fullWidth onClick={() => update({ toast: 'Enter 6-digit code…' })}>Enter code manually</PillButton>
        </div>
      </div>
    </Phone>
  );
}

// ─── CHECK-IN SUCCESS (modal-like screen) ───
function CheckInSuccessScreen() {
  const { go, route, state } = useRoute();
  const gym = GYMS.find(g => g.id === route.params.gymId) || GYMS[0];
  const sub = state.subscription;
  return (
    <Phone>
      <div style={{ padding: 24, display: 'flex', flexDirection: 'column', height: '100%', alignItems: 'center' }}>
        <div style={{ flex: 0.7 }}/>
        <div style={{ position: 'relative', width: 160, height: 160, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {[0,1,2].map(i => <div key={i} style={{ position: 'absolute', inset: -i*20, borderRadius: 100, border: `1.5px solid ${GP.lime}${['ff','44','22'][i]}`, animation: `gpRing 2.4s ease-out ${i*0.3}s infinite` }}/>)}
          <div style={{ width: 110, height: 110, borderRadius: 100, background: `linear-gradient(180deg, ${GP.lime2}, ${GP.lime})`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 60px ${GP.lime}88` }}>
            <I path="check" size={50} color="#0A0B0A" stroke={3}/>
          </div>
        </div>
        <div style={{ textAlign: 'center', marginTop: 36 }}>
          <Display size={42}>YOU'RE <SerifAccent size={42}>in.</SerifAccent></Display>
          <div style={{ marginTop: 10, fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 22, color: GP.ink, letterSpacing: '-0.03em' }}>{gym.name.toUpperCase()}</div>
          <Mono color={GP.ink3} tracking={0.18} style={{ marginTop: 6 }}>● {new Date().toTimeString().slice(0,5)} · {gym.area.toUpperCase()}</Mono>
        </div>

        <div style={{ marginTop: 26, width: '100%', padding: 14, borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', justifyContent: 'space-around' }}>
          <Stat label="THIS VISIT" value="#24"/>
          <Stat label="REMAINING" value={`${sub ? sub.visitsTotal - sub.visitsUsed : 0}`} color={GP.lime}/>
          <Stat label="STREAK" value="15d"/>
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth onClick={() => go('home')}>DONE →</PillButton>
          <PillButton fullWidth onClick={() => go('gymDetail', { id: gym.id })}>Club details</PillButton>
        </div>
      </div>
    </Phone>
  );
}
function Stat({ label, value, color = GP.ink }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 22, color, letterSpacing: '-0.03em' }}>{value}</div>
      <Mono size={9} color={GP.ink3} tracking={0.14}>{label}</Mono>
    </div>
  );
}

// ─── PROFILE ───
function ProfileScreen() {
  const { go, state } = useRoute();
  const sub = state.subscription;
  const t = sub ? TIERS[sub.tier] : null;
  const initials = (state.auth.name || 'MA').split(' ').map(s=>s[0]).slice(0,2).join('').toUpperCase();
  const pct = sub ? (sub.visitsUsed / sub.visitsTotal) : 0;
  const dash = 264;
  return (
    <Phone>
      <div style={{ padding: '10px 20px 140px', overflowY: 'auto', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
          <Overline color={GP.ink3}>● YOU</Overline>
          <IconBtn icon={<I path="gear" size={18}/>} onClick={() => go('settings')}/>
        </div>

        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          <div style={{ width: 72, height: 72, borderRadius: 100, background: `linear-gradient(135deg, ${GP.lime2}, ${GP.lime})`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: '#0A0B0A', letterSpacing: '-0.04em' }}>{initials}</div>
          <div>
            <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 22, color: GP.ink, letterSpacing: '-0.03em' }}>{(state.auth.name || 'Mohammad A.').toUpperCase()}</div>
            <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 4, letterSpacing: '0.1em' }}>
              {sub ? `${t.glyph} ${t.name.toUpperCase()} · SINCE AUG 2024` : '○ NO ACTIVE PLAN'}
            </div>
          </div>
        </div>

        {sub && (
          <div style={{ marginTop: 22, padding: 18, borderRadius: 20, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', gap: 18, alignItems: 'center' }}>
            <div style={{ position: 'relative', width: 100, height: 100 }}>
              <svg width="100" height="100" viewBox="0 0 100 100" style={{ transform: 'rotate(-90deg)' }}>
                <circle cx="50" cy="50" r="42" fill="none" stroke={GP.bg3} strokeWidth="8"/>
                <circle cx="50" cy="50" r="42" fill="none" stroke={GP.lime} strokeWidth="8" strokeLinecap="round" strokeDasharray={dash} strokeDashoffset={dash * (1 - pct)} style={{ filter: `drop-shadow(0 0 6px ${GP.lime}aa)`, transition: 'stroke-dashoffset 400ms ease' }}/>
              </svg>
              <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
                <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: GP.ink, letterSpacing: '-0.04em', lineHeight: 1 }}>{sub.visitsUsed}</div>
                <Mono size={9} color={GP.ink3} tracking={0.14}>/ {sub.visitsTotal}</Mono>
              </div>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[['STREAK', '14 DAYS', GP.lime], ['THIS MO', `${sub.visitsUsed} VISITS`, GP.ink], ['NEXT', 'DIAMOND', '#9EE7FF']].map(([k,v,c]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: GP.fMono, fontSize: 11 }}>
                  <span style={{ color: GP.ink3, letterSpacing: '0.1em' }}>{k}</span>
                  <span style={{ color: c, fontWeight: 600 }}>{v}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div style={{ marginTop: 18, borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}`, overflow: 'hidden' }}>
          {[
            ['Subscription', sub ? `${t.glyph} ${t.name}` : 'None', () => go('mySubscription')],
            ['Payment methods', '•••• 4421', () => {}],
            ['Guest passes', '2 left', () => {}],
            ['Visit history', `${sub?.visitsUsed || 0}`, () => {}],
            ['Notifications', '3 new', () => go('notifications')],
            ['Settings', 'EN · ع', () => go('settings')],
          ].map(([k, v, onClick], i, a) => (
            <button key={k} onClick={onClick} style={{ all: 'unset', cursor: 'pointer', display: 'flex', padding: '14px 16px', alignItems: 'center', justifyContent: 'space-between', borderBottom: i < a.length-1 ? `1px solid ${GP.border}` : 'none', width: '100%', boxSizing: 'border-box' }}>
              <div style={{ fontSize: 15, color: GP.ink }}>{k}</div>
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <span style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3 }}>{v}</span>
                <I path="chev" size={14} color={GP.ink4}/>
              </div>
            </button>
          ))}
        </div>
      </div>
      <TabBar active="profile" onTab={k => go(k)} onCenter={() => go('scan')}/>
    </Phone>
  );
}

// ─── MY SUBSCRIPTION ───
function MySubscriptionScreen() {
  const { go, state, update } = useRoute();
  const sub = state.subscription;
  if (!sub) { React.useEffect(() => go('plans'), []); return <Phone/>; }
  const t = TIERS[sub.tier];
  const pct = sub.visitsUsed / sub.visitsTotal * 100;
  return (
    <Phone>
      <div style={{ padding: '10px 20px 40px', overflowY: 'auto', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('profile')}/>} title="● SUBSCRIPTION"/>

        <div style={{ padding: '8px 0' }}>
          <Display size={36}>YOUR <SerifAccent size={36}>plan.</SerifAccent></Display>
        </div>

        {/* Big tier card */}
        <div style={{ marginTop: 18, padding: 22, borderRadius: 24, background: GP.bg2, border: `1px solid ${t.color}55`, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -60, right: -60, width: 220, height: 220, borderRadius: 100, background: `radial-gradient(circle, ${t.color}33, transparent 65%)` }}/>
          <div style={{ position: 'relative' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <TierChip tier={sub.tier} size={11}/>
              <Mono size={10} color={GP.green} tracking={0.14}>● ACTIVE</Mono>
            </div>
            <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 64, color: t.color, letterSpacing: '-0.045em', lineHeight: 1, marginTop: 16 }}>
              {t.name.toUpperCase()}
            </div>
            <Mono color={GP.ink3} tracking={0.14} style={{ marginTop: 10 }}>RENEWS {sub.nextRenew.toUpperCase()} · {t.price} JOD/MO</Mono>

            <div style={{ marginTop: 22, height: 8, borderRadius: 100, background: 'rgba(255,255,255,0.06)', overflow: 'hidden' }}>
              <div style={{ width: `${pct}%`, height: '100%', background: `linear-gradient(90deg, ${GP.lime}, ${GP.lime2})`, boxShadow: `0 0 10px ${GP.lime}`, borderRadius: 100 }}/>
            </div>
            <div style={{ marginTop: 8, display: 'flex', justifyContent: 'space-between' }}>
              <Mono color={GP.ink2} tracking={0.14}>{sub.visitsUsed} USED</Mono>
              <Mono color={GP.ink2} tracking={0.14}>{sub.visitsTotal - sub.visitsUsed} LEFT · {sub.visitsTotal} TOTAL</Mono>
            </div>
          </div>
        </div>

        {/* Perks */}
        <div style={{ marginTop: 20 }}>
          <Overline color={GP.ink3}>● YOUR PERKS</Overline>
          <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {t.features.map((f, i) => (
              <div key={i} style={{ padding: '12px 14px', borderRadius: 14, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', gap: 10, alignItems: 'center' }}>
                <div style={{ width: 26, height: 26, borderRadius: 8, background: `${t.color}14`, border: `1px solid ${t.color}44`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <I path="check" size={14} color={t.color} stroke={2.5}/>
                </div>
                <div style={{ flex: 1, fontSize: 14, color: GP.ink }}>{f}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Upgrade / Cancel */}
        <div style={{ marginTop: 22, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {t.rank < 3 && <PillButton primary fullWidth onClick={() => go('plans')}>UPGRADE TO {TIERS[Object.keys(TIERS)[t.rank + 1]].name.toUpperCase()} →</PillButton>}
          <PillButton fullWidth onClick={() => update({ toast: 'Plan will end on renewal date' })}>Cancel renewal</PillButton>
        </div>

        {/* Recent visits */}
        <div style={{ marginTop: 22 }}>
          <Overline color={GP.ink3}>● RECENT VISITS</Overline>
          <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[['Iron Forge','Yesterday · 18:22'],['Fortis Boxing','Nov 2 · 19:04'],['Iron Forge','Oct 31 · 07:10']].map(([n, w], i) => (
              <div key={i} style={{ padding: '12px 14px', borderRadius: 14, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontFamily: GP.fDisplay, fontStyle: 'italic', fontWeight: 900, fontSize: 14, color: GP.ink, letterSpacing: '-0.02em' }}>{n.toUpperCase()}</div>
                  <Mono size={10} color={GP.ink3} tracking={0.1}>{w}</Mono>
                </div>
                <Mono size={10} color={GP.lime} tracking={0.14}>● CHECKED IN</Mono>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Phone>
  );
}

// ─── NOTIFICATIONS ───
function NotificationsScreen() {
  const { go } = useRoute();
  return (
    <Phone>
      <div style={{ padding: '10px 20px 40px', overflowY: 'auto', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('home')}/>} title="● INBOX" right={null}/>
        <div style={{ padding: '8px 0' }}>
          <Display size={36}>YOUR <SerifAccent size={36}>inbox.</SerifAccent></Display>
        </div>

        <div style={{ marginTop: 14, display: 'flex', gap: 8 }}>
          {['ALL','UNREAD','CHECK-IN','PROMO'].map((f, i) => (
            <button key={f} style={{ all: 'unset', cursor: 'pointer', padding: '6px 12px', borderRadius: 100, fontFamily: GP.fMono, fontSize: 10, letterSpacing: '0.14em', color: i === 0 ? '#0A0B0A' : GP.ink2, background: i === 0 ? GP.lime : GP.bg2, border: `1px solid ${i === 0 ? GP.lime : GP.border2}` }}>{f}</button>
          ))}
        </div>

        <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {NOTIFS.map(n => (
            <div key={n.id} style={{ padding: 14, borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}`, display: 'flex', gap: 12 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: `${n.color}14`, border: `1px solid ${n.color}44`, color: n.color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: GP.fMono, fontSize: 16, flexShrink: 0 }}>{n.glyph}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                  <div style={{ color: GP.ink, fontSize: 14, fontWeight: 600 }}>{n.title}</div>
                  <Mono size={9} color={GP.ink3} tracking={0.12} style={{ flexShrink: 0 }}>{n.when.toUpperCase()}</Mono>
                </div>
                <div style={{ color: GP.ink3, fontSize: 13, marginTop: 4, lineHeight: 1.5 }}>{n.body}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// ─── SETTINGS ───
function SettingsScreen() {
  const { go, state, update } = useRoute();
  const [theme, setTheme] = React.useState('dark');
  const locale = state.locale;
  const section = (title, rows) => (
    <div style={{ marginTop: 16 }}>
      <Overline color={GP.ink3}>● {title}</Overline>
      <div style={{ marginTop: 8, borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}`, overflow: 'hidden' }}>
        {rows.map((r, i) => (
          <div key={i} style={{ padding: '14px 16px', borderBottom: i < rows.length - 1 ? `1px solid ${GP.border}` : 'none' }}>
            {r}
          </div>
        ))}
      </div>
    </div>
  );
  const toggle = (on) => (
    <div style={{ width: 40, height: 24, borderRadius: 100, background: on ? GP.lime : GP.bg3, border: `1px solid ${on ? 'transparent' : GP.border2}`, position: 'relative', transition: 'all 200ms' }}>
      <div style={{ position: 'absolute', top: 2, left: on ? 18 : 2, width: 18, height: 18, borderRadius: 100, background: on ? '#0A0B0A' : GP.ink3, transition: 'left 200ms' }}/>
    </div>
  );
  return (
    <Phone>
      <div style={{ padding: '10px 20px 40px', overflowY: 'auto', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('profile')}/>} title="● SETTINGS"/>

        <div style={{ padding: '4px 0' }}>
          <Display size={36}>SETTINGS.</Display>
        </div>

        {section('APPEARANCE', [
          <div style={{ display: 'flex', gap: 8 }}>
            {[['dark','DARK','moon'],['light','LIGHT','sun'],['system','SYSTEM','gear']].map(([k, label, ic]) => (
              <button key={k} onClick={() => setTheme(k)} style={{ all: 'unset', cursor: 'pointer', flex: 1, padding: '12px 4px', borderRadius: 14, background: theme === k ? 'rgba(187,251,70,0.08)' : GP.bg3, border: `1px solid ${theme === k ? 'rgba(187,251,70,0.4)' : GP.border2}`, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, color: theme === k ? GP.lime : GP.ink2 }}>
                <I path={ic} size={18}/>
                <Mono size={9} color={theme === k ? GP.lime : GP.ink3} tracking={0.16}>{label}</Mono>
              </button>
            ))}
          </div>,
        ])}

        {section('LANGUAGE', [
          <div style={{ display: 'flex', gap: 8 }}>
            {[['en','EN · ENGLISH'],['ar','ع · العربية']].map(([k, label]) => (
              <button key={k} onClick={() => update({ locale: k })} style={{ all: 'unset', cursor: 'pointer', flex: 1, padding: '12px 6px', borderRadius: 14, background: locale === k ? 'rgba(187,251,70,0.08)' : GP.bg3, border: `1px solid ${locale === k ? 'rgba(187,251,70,0.4)' : GP.border2}`, textAlign: 'center', color: locale === k ? GP.lime : GP.ink }}>
                <div style={{ fontFamily: GP.fMono, fontSize: 11, letterSpacing: '0.16em' }}>{label}</div>
              </button>
            ))}
          </div>,
        ])}

        {section('NOTIFICATIONS', [
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><span style={{ color: GP.ink, fontSize: 14 }}>Plan reminders</span>{toggle(true)}</div>,
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><span style={{ color: GP.ink, fontSize: 14 }}>New clubs near me</span>{toggle(true)}</div>,
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><span style={{ color: GP.ink, fontSize: 14 }}>Promos & offers</span>{toggle(false)}</div>,
        ])}

        {section('ACCOUNT', [
          <button onClick={() => {}} style={{ all: 'unset', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}><span style={{ color: GP.ink, fontSize: 14 }}>Edit profile</span><I path="chev" size={14} color={GP.ink4}/></button>,
          <button onClick={() => {}} style={{ all: 'unset', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}><span style={{ color: GP.ink, fontSize: 14 }}>Privacy & security</span><I path="chev" size={14} color={GP.ink4}/></button>,
          <button onClick={() => { update(defaultState()); go('login'); }} style={{ all: 'unset', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', color: GP.red }}>
            <span style={{ fontSize: 14 }}>Log out</span><I path="logout" size={14}/>
          </button>,
        ])}

        <div style={{ marginTop: 22, textAlign: 'center', fontFamily: GP.fMono, fontSize: 10, color: GP.ink4, letterSpacing: '0.14em' }}>
          GYMPASS v1.0 · MADE IN AMMAN
        </div>
      </div>
    </Phone>
  );
}
// re-declare for logout reset
function defaultState() {
  return { route: { name: 'splash', params: {} }, history: [], auth: { phone: '', name: '', authed: false }, subscription: null, lastCheckIn: null, filter: 'ALL', locale: 'en', toast: null };
}

Object.assign(window, {
  HomeScreen, GymsScreen, GymDetailScreen, ScanScreen, CheckInSuccessScreen,
  ProfileScreen, MySubscriptionScreen, NotificationsScreen, SettingsScreen, defaultState,
});
