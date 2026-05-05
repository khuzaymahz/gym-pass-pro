// Auth & onboarding screens: Splash, Login, OTP, Register, Plans, Payment, Success

function SplashScreen() {
  const { go, state, update } = useRoute();
  React.useEffect(() => {
    const t = setTimeout(() => {
      if (state.auth.authed) go(state.subscription ? 'home' : 'plans');
      else go('login');
    }, 1400);
    return () => clearTimeout(t);
  }, []);
  return (
    <Phone>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
        <div style={{ position: 'relative' }}>
          <div style={{ position: 'absolute', inset: -40, borderRadius: 100, background: `radial-gradient(circle, ${GP.lime}33, transparent 60%)`, animation: 'gpPulse 2.2s ease-out infinite' }}/>
          <Wordmark size={52}/>
        </div>
        <Mono size={10} color={GP.ink3} tracking={0.24}>● ONE PASS · EVERY GYM</Mono>
      </div>
    </Phone>
  );
}

function LoginScreen() {
  const { go, update } = useRoute();
  const [phone, setPhone] = React.useState('79 123 4567');
  return (
    <Phone>
      <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Wordmark size={26}/>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 22 }}>
          <Overline>● ONE SUB · EVERY GYM</Overline>
          <div>
            <Display size={52}>ONE PASS.</Display>
            <Display size={52}>EVERY <SerifAccent size={52}>gym</SerifAccent>.</Display>
          </div>
          <div style={{ color: GP.ink3, fontSize: 15, lineHeight: 1.5, maxWidth: 280 }}>
            Browse 120+ clubs across Jordan. Pick a tier. Check in with a scan.
          </div>

          <div style={{ marginTop: 6 }}>
            <Mono size={10} color={GP.ink3} tracking={0.18}>● PHONE NUMBER</Mono>
            <div style={{ marginTop: 8, display: 'flex', gap: 8, alignItems: 'center', padding: '14px 16px', background: GP.bg2, border: `1px solid ${GP.border2}`, borderRadius: 28 }}>
              <span style={{ fontFamily: GP.fMono, fontSize: 14, color: GP.ink2, paddingRight: 10, borderRight: `1px solid ${GP.border}` }}>🇯🇴 +962</span>
              <input value={phone} onChange={e => setPhone(e.target.value)} style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: GP.ink, fontFamily: GP.fMono, fontSize: 15, letterSpacing: '0.05em' }}/>
            </div>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth onClick={() => { update({ auth: { phone, name: '', authed: false } }); go('otp'); }}>CONTINUE →</PillButton>
          <div style={{ textAlign: 'center', fontFamily: GP.fMono, fontSize: 10, color: GP.ink4, letterSpacing: '0.14em', marginTop: 4 }}>
            ◆ MADE IN AMMAN · ع EN
          </div>
        </div>
      </div>
    </Phone>
  );
}

function OtpScreen() {
  const { go, state, update } = useRoute();
  const [code, setCode] = React.useState(['', '', '', '']);
  const [active, setActive] = React.useState(0);
  const refs = React.useRef([]);
  const setCell = (i, v) => {
    const next = [...code]; next[i] = v.slice(-1); setCode(next);
    if (v && i < 3) { setActive(i+1); refs.current[i+1]?.focus(); }
  };
  const filled = code.every(c => c.length === 1);
  React.useEffect(() => { refs.current[0]?.focus(); }, []);
  return (
    <Phone>
      <div style={{ padding: '10px 24px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('login')}/>} title="● STEP 2 OF 3 — VERIFY"/>

        <div style={{ marginTop: 18 }}>
          <Display size={44}>ALMOST <SerifAccent size={44}>there.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>
            We sent a 4-digit code to <span style={{ color: GP.ink, fontFamily: GP.fMono }}>+962 {state.auth.phone}</span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', marginTop: 44 }}>
          {code.map((c, i) => (
            <input key={i} ref={el => refs.current[i] = el} value={c} onChange={e => setCell(i, e.target.value)} onFocus={() => setActive(i)}
              style={{
                width: 62, height: 78, borderRadius: 20,
                background: GP.bg2, border: `1px solid ${active === i ? GP.lime : GP.border2}`,
                boxShadow: active === i ? `0 0 0 3px rgba(187,251,70,0.12)` : 'none',
                color: GP.ink, fontFamily: GP.fDisplay, fontStyle: 'italic', fontWeight: 900, fontSize: 36, textAlign: 'center', outline: 'none',
              }}/>
          ))}
        </div>

        <div style={{ textAlign: 'center', marginTop: 26, fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, letterSpacing: '0.14em' }}>
          RESEND IN <span style={{ color: GP.lime }}>0:28</span>
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth disabled={!filled} onClick={() => { go('register'); }}>VERIFY →</PillButton>
          <PillButton fullWidth onClick={() => setCode(['1','2','3','4'])}>Autofill for demo</PillButton>
        </div>
      </div>
    </Phone>
  );
}

function RegisterScreen() {
  const { go, update, state } = useRoute();
  const [name, setName] = React.useState(state.auth.name || 'Mohammad A.');
  const [email, setEmail] = React.useState('mohammad@mail.com');
  return (
    <Phone>
      <div style={{ padding: '10px 24px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('otp')}/>} title="● STEP 3 OF 3 — YOU"/>
        <div style={{ marginTop: 18 }}>
          <Display size={44}>YOU'RE <SerifAccent size={44}>new.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>Tell us what to call you.</div>
        </div>

        <div style={{ marginTop: 30, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Field label="● FULL NAME" value={name} onChange={setName}/>
          <Field label="● EMAIL" value={email} onChange={setEmail}/>
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginTop: 4, padding: 12, borderRadius: 14, background: 'rgba(187,251,70,0.06)', border: '1px solid rgba(187,251,70,0.18)' }}>
            <div style={{ width: 16, height: 16, borderRadius: 4, background: GP.lime, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <I path="check" size={11} color="#0A0B0A" stroke={3}/>
            </div>
            <div style={{ fontSize: 12, color: GP.ink2, lineHeight: 1.5 }}>I agree to the <span style={{ color: GP.lime }}>Terms</span> and <span style={{ color: GP.lime }}>Privacy Policy</span>.</div>
          </div>
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ paddingBottom: 40 }}>
          <PillButton primary fullWidth onClick={() => { update({ auth: { ...state.auth, name, authed: true } }); go('plans'); }}>CREATE ACCOUNT →</PillButton>
        </div>
      </div>
    </Phone>
  );
}
function Field({ label, value, onChange, mono }) {
  return (
    <div>
      <Mono size={10} color={GP.ink3} tracking={0.18}>{label}</Mono>
      <div style={{ marginTop: 6, padding: '14px 18px', background: GP.bg2, border: `1px solid ${GP.border2}`, borderRadius: 28 }}>
        <input value={value} onChange={e => onChange(e.target.value)} style={{ width: '100%', background: 'transparent', border: 'none', outline: 'none', color: GP.ink, fontFamily: mono ? GP.fMono : GP.fBody, fontSize: 15 }}/>
      </div>
    </div>
  );
}

// ─── PLANS ───
function PlansScreen() {
  const { go, state, update } = useRoute();
  const [sel, setSel] = React.useState(state.subscription?.tier === 'gold' ? 'platinum' : (state.subscription?.tier ? 'diamond' : 'gold'));
  const current = state.subscription?.tier;
  const cur = TIERS[sel];
  const tierCard = (key) => {
    const t = TIERS[key];
    const selected = sel === key;
    const isCurrent = current === key;
    return (
      <button key={key} onClick={() => setSel(key)} style={{ all: 'unset', cursor: 'pointer', display: 'block' }}>
        <div style={{
          padding: 18, borderRadius: 20,
          background: selected ? GP.bg2 : 'rgba(255,255,255,0.02)',
          border: `1px solid ${selected ? t.color + '77' : GP.border}`,
          position: 'relative', overflow: 'hidden',
          boxShadow: selected ? `0 0 0 3px ${t.color}14` : 'none',
          transition: 'all 180ms ease',
        }}>
          {selected && <div style={{ position: 'absolute', top: -30, right: -30, width: 160, height: 160, borderRadius: 100, background: `radial-gradient(circle, ${t.color}22, transparent 65%)` }}/>}
          <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                <TierChip tier={key}/>
                {isCurrent && <span style={{ fontFamily: GP.fMono, fontSize: 9, color: GP.lime, letterSpacing: '0.14em', padding: '3px 7px', background: 'rgba(187,251,70,0.1)', border: '1px solid rgba(187,251,70,0.3)', borderRadius: 4 }}>CURRENT</span>}
              </div>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 32, letterSpacing: '-0.035em', color: GP.ink, marginTop: 10 }}>{t.visits} VISITS</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, marginTop: 2 }}>per month</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 28, color: GP.ink, letterSpacing: '-0.03em' }}>{t.price}</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3 }}>JOD / MO</div>
            </div>
          </div>
          <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {t.features.map((f, i) => (
              <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13, color: GP.ink2 }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={t.color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.check}/></svg>
                {f}
              </div>
            ))}
          </div>
        </div>
      </button>
    );
  };
  const backTo = state.auth.authed && state.subscription ? 'profile' : 'register';
  const isOnboarding = !state.subscription; // onboarding = no plan yet
  const skipBtn = isOnboarding ? (
    <button
      onClick={() => go('home')}
      style={{
        all: 'unset', cursor: 'pointer',
        padding: '7px 14px', borderRadius: 100,
        background: 'rgba(255,255,255,0.04)',
        border: `1px solid ${GP.border2}`,
        fontFamily: GP.fMono, fontSize: 10, color: GP.ink2,
        letterSpacing: '0.18em', textTransform: 'uppercase',
      }}
    >SKIP →</button>
  ) : null;
  return (
    <Phone>
      <div style={{ padding: '10px 20px 110px', overflowY: 'auto', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go(backTo)}/>} title="● CHOOSE YOUR TIER" right={skipBtn}/>
        <div style={{ padding: '8px 0 2px' }}>
          <Display size={42}>PICK A <SerifAccent size={42}>pass.</SerifAccent></Display>
          <div style={{ color: GP.ink3, fontSize: 14, marginTop: 8 }}>More gyms, more visits, more everything.</div>
        </div>
        <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
          {['silver','gold','platinum','diamond'].map(tierCard)}
        </div>
        <div style={{ marginTop: 18, fontFamily: GP.fMono, fontSize: 10, color: GP.ink4, letterSpacing: '0.14em', textAlign: 'center' }}>
          CANCEL ANYTHING · CHANGE TIERS ANY TIME
        </div>
      </div>
      <div style={{ position: 'absolute', bottom: 24, left: 20, right: 20 }}>
        <PillButton primary fullWidth onClick={() => go('payment', { tier: sel })}>CONTINUE WITH {cur.name.toUpperCase()} →</PillButton>
      </div>
    </Phone>
  );
}

// ─── PAYMENT ───
function PaymentScreen() {
  const { go, route, state, update } = useRoute();
  const tierKey = route.params.tier || 'gold';
  const t = TIERS[tierKey];
  const [method, setMethod] = React.useState('card');
  const [processing, setProcessing] = React.useState(false);
  const pay = () => {
    setProcessing(true);
    setTimeout(() => {
      update({
        subscription: {
          tier: tierKey, visitsUsed: state.subscription?.visitsUsed || 0, visitsTotal: t.visits,
          startedAt: Date.now(), nextRenew: 'Nov 14',
        },
        auth: { ...state.auth, authed: true },
      });
      go('success', { tier: tierKey });
    }, 1100);
  };
  return (
    <Phone>
      <div style={{ padding: '10px 20px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <TopBar left={<BackBtn onClick={() => go('plans')}/>} title="● CHECKOUT"/>
        <div style={{ padding: '8px 0' }}>
          <Display size={44}>ALMOST <SerifAccent size={44}>there.</SerifAccent></Display>
        </div>

        {/* order summary */}
        <div style={{ marginTop: 18, padding: 16, borderRadius: 20, background: GP.bg2, border: `1px solid ${GP.border}`, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 140, height: 140, borderRadius: 100, background: `radial-gradient(circle, ${t.color}22, transparent 65%)` }}/>
          <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <TierChip tier={tierKey}/>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 24, color: GP.ink, marginTop: 10, letterSpacing: '-0.03em' }}>{t.visits} VISITS / MO</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3, marginTop: 4 }}>MONTHLY · CANCEL ANYTIME</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: 30, color: GP.ink, letterSpacing: '-0.03em' }}>{t.price}</div>
              <div style={{ fontFamily: GP.fMono, fontSize: 10, color: GP.ink3 }}>JOD / MO</div>
            </div>
          </div>
        </div>

        {/* payment method */}
        <div style={{ marginTop: 22 }}>
          <Mono size={10} color={GP.ink3}>● PAYMENT METHOD</Mono>
          <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[
              { k:'card',  label:'Visa •••• 4421',  sub:'Exp 09/28',       icon:'card' },
              { k:'apple', label:'Apple Pay',       sub:'Default method',  icon:'card' },
            ].map(opt => {
              const on = method === opt.k;
              return (
                <button key={opt.k} onClick={() => setMethod(opt.k)} style={{ all: 'unset', cursor: 'pointer', display: 'flex', gap: 12, alignItems: 'center', padding: '12px 14px', borderRadius: 16, background: on ? 'rgba(187,251,70,0.06)' : GP.bg2, border: `1px solid ${on ? 'rgba(187,251,70,0.4)' : GP.border}` }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: GP.bg3, display: 'flex', alignItems: 'center', justifyContent: 'center', color: on ? GP.lime : GP.ink2 }}><I path={opt.icon} size={18}/></div>
                  <div style={{ flex: 1 }}>
                    <div style={{ color: GP.ink, fontSize: 14, fontWeight: 600 }}>{opt.label}</div>
                    <div style={{ color: GP.ink3, fontFamily: GP.fMono, fontSize: 10, marginTop: 2, letterSpacing: '0.1em' }}>{opt.sub}</div>
                  </div>
                  <div style={{ width: 20, height: 20, borderRadius: 100, border: `2px solid ${on ? GP.lime : GP.ink4}`, background: on ? GP.lime : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {on && <div style={{ width: 8, height: 8, borderRadius: 100, background: '#0A0B0A' }}/>}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* total */}
        <div style={{ marginTop: 20, padding: '14px 16px', borderRadius: 16, background: GP.bg2, border: `1px solid ${GP.border}` }}>
          {[['Subtotal', `${t.price}.00 JOD`], ['VAT (16%)', `${(t.price*0.16).toFixed(2)} JOD`]].map(([k,v]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: GP.ink2, padding: '2px 0' }}>
              <span>{k}</span><span style={{ fontFamily: GP.fMono }}>{v}</span>
            </div>
          ))}
          <div style={{ height: 1, background: GP.border, margin: '10px 0' }}/>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontFamily: GP.fMono, fontSize: 11, color: GP.ink3, letterSpacing: '0.14em' }}>TOTAL</span>
            <span style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', color: GP.lime, fontSize: 22, letterSpacing: '-0.02em' }}>{(t.price*1.16).toFixed(2)} JOD</span>
          </div>
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ paddingBottom: 40 }}>
          <PillButton primary fullWidth disabled={processing} onClick={pay}>
            {processing ? 'PROCESSING…' : `PAY ${(t.price*1.16).toFixed(0)} JOD →`}
          </PillButton>
        </div>
      </div>
    </Phone>
  );
}

// ─── SUCCESS (subscription active) ───
function SuccessScreen() {
  const { go, route, state } = useRoute();
  const tierKey = route.params.tier || state.subscription?.tier || 'gold';
  const t = TIERS[tierKey];
  return (
    <Phone>
      <div style={{ padding: 24, display: 'flex', flexDirection: 'column', height: '100%', alignItems: 'center' }}>
        <div style={{ flex: 1 }}/>
        <div style={{ position: 'relative', width: 180, height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {[0,1,2].map(i => (
            <div key={i} style={{
              position: 'absolute', inset: -i*22, borderRadius: 100,
              border: `1.5px solid ${GP.lime}${['ff','66','22'][i]}`,
              boxShadow: i === 0 ? `0 0 40px ${GP.lime}66` : 'none',
              animation: `gpRing 2.4s ease-out ${i*0.3}s infinite`,
            }}/>
          ))}
          <div style={{ width: 120, height: 120, borderRadius: 100, background: `linear-gradient(180deg, ${GP.lime2}, ${GP.lime})`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 60px ${GP.lime}88` }}>
            <I path="check" size={56} color="#0A0B0A" stroke={3}/>
          </div>
        </div>
        <div style={{ textAlign: 'center', marginTop: 44 }}>
          <Display size={46}>YOU'RE IN.</Display>
          <Display size={36}><SerifAccent size={40}>welcome to</SerifAccent></Display>
          <Display size={46} color={t.color}>{t.glyph} {t.name.toUpperCase()}.</Display>
        </div>
        <div style={{ color: GP.ink3, fontSize: 14, marginTop: 18, textAlign: 'center', maxWidth: 280 }}>
          {t.visits} visits/month · 120+ clubs · renews Nov 14
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 40 }}>
          <PillButton primary fullWidth onClick={() => go('home')}>FIND YOUR FIRST GYM →</PillButton>
          <PillButton fullWidth onClick={() => go('home')}>View receipt</PillButton>
        </div>
      </div>
    </Phone>
  );
}

Object.assign(window, { SplashScreen, LoginScreen, OtpScreen, RegisterScreen, PlansScreen, PaymentScreen, SuccessScreen });
