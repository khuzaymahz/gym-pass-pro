// GymPass prototype — shared primitives, router, state store.

const GP = {
  bg: '#0A0B0A', bg2: '#171A19', bg3: '#1E2221', bg1: '#111312',
  lime: '#BBFB46', lime2: '#D5FF7E',
  ink: '#F4F4F0', ink2: '#CACBC2', ink3: '#8E8F86', ink4: '#5A5B54',
  border: 'rgba(255,255,255,0.08)', border2: 'rgba(255,255,255,0.14)',
  red: '#FF453A', green: '#30D158', yellow: '#FFD60A', blue: '#61CDFF', purple: '#BF5AF2', orange: '#FF7351',
  fDisplay: "'Archivo', system-ui, sans-serif",
  fBody: "'Inter', system-ui, sans-serif",
  fMono: "'JetBrains Mono', monospace",
  fSerif: "'Instrument Serif', serif",
};

const TIERS = {
  silver:   { name: 'Silver',   glyph: '◇', color: '#C0C0C0', price: 25, visits: 12, rank: 0, features: ['50+ basic gyms', 'Business hours'] },
  gold:     { name: 'Gold',     glyph: '◆', color: '#FFD60A', price: 45, visits: 30, rank: 1, features: ['120+ gyms', 'Extended hours', '5 guest passes'] },
  platinum: { name: 'Platinum', glyph: '◈', color: '#E0E6FF', price: 75, visits: 60, rank: 2, features: ['All 220 clubs', '24/7 access', 'Classes included'] },
  diamond:  { name: 'Diamond',  glyph: '◉', color: '#64D2FF', price: 110, visits: 90, rank: 3, features: ['Every venue', '24/7 + guest', 'PT sessions', 'Spa & pool'] },
};

const GYMS = [
  { id: 'iron-forge',    name: 'Iron Forge',     cat: 'GYM',       color: '#BBFB46', dist: '0.4 km', area: 'Abdoun',     state: 'OPEN', minTier: 'silver',   rating: 4.8, reviews: 412, hours: '06:00–23:00', amenities: ['Wi-Fi','Parking','Showers','Lockers'] },
  { id: 'bedford-yoga',  name: 'Bedford Yoga',   cat: 'YOGA',      color: '#BF5AF2', dist: '0.8 km', area: 'Sweifieh',   state: 'OPEN', minTier: 'gold',     rating: 4.9, reviews: 208, hours: '07:00–22:00', amenities: ['Mats','Showers','Towels','Tea'] },
  { id: 'fortis-boxing', name: 'Fortis Boxing',  cat: 'MARTIAL',   color: '#FF453A', dist: '1.2 km', area: 'Jabal Amman',state: 'BUSY', minTier: 'gold',     rating: 4.7, reviews: 331, hours: '10:00–00:00', amenities: ['Ring','Bags','Coaches','Lockers'] },
  { id: 'apex-crossfit', name: 'Apex CrossFit',  cat: 'CROSSFIT',  color: '#30D158', dist: '2.1 km', area: 'Khalda',     state: 'OPEN', minTier: 'platinum', rating: 4.9, reviews: 527, hours: '05:00–23:00', amenities: ['Olympic bars','Rigs','Classes','Sauna'] },
  { id: 'halo-studio',   name: 'Halo Studio',    cat: 'YOGA',      color: '#BF5AF2', dist: '2.6 km', area: 'Abdali',     state: 'CLOSED', minTier: 'silver', rating: 4.6, reviews: 142, hours: '08:00–21:00', amenities: ['Mats','Bolsters','Showers'] },
  { id: 'core-athletic', name: 'Core Athletic',  cat: 'GYM',       color: '#BBFB46', dist: '3.4 km', area: 'Deir Ghbar', state: 'OPEN', minTier: 'silver',   rating: 4.5, reviews: 289, hours: '24 / 7',       amenities: ['Wi-Fi','Parking','Pool','Sauna'] },
];

const NOTIFS = [
  { id: 1, type: 'expire', title: 'Plan expires in 14 days', body: 'Your Gold pass renews on Nov 14. Tap to manage.',                when: '2 h ago',  color: '#FFD60A', glyph: '◆' },
  { id: 2, type: 'checkin',title: 'Checked in: Iron Forge',  body: 'Have a great workout! 23 of 30 visits used this month.',       when: 'Yesterday',color: '#BBFB46', glyph: '●' },
  { id: 3, type: 'promo',  title: 'New club: Apex CrossFit', body: 'Platinum members now get access to Apex in Khalda.',           when: '2 d ago',  color: '#64D2FF', glyph: '◉' },
  { id: 4, type: 'guest',  title: 'Guest pass accepted',     body: 'Layla used one of your guest passes at Bedford Yoga.',         when: '4 d ago',  color: '#BF5AF2', glyph: '●' },
];

// ─── Icons ───
const IconPaths = {
  home: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9 22V12h6v10',
  map: 'M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z',
  user: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.35-4.35',
  bell: 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0',
  arrow: 'M5 12h14M12 5l7 7-7 7',
  back: 'M19 12H5M12 19l-7-7 7-7',
  chev: 'M9 18l6-6-6-6',
  check: 'M20 6L9 17l-5-5',
  heart: 'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
  flame: 'M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.3 1-3a2.5 2.5 0 0 0 2.5 2.5z',
  clock: 'M12 8v4l3 2',
  gear: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  plus: 'M12 5v14M5 12h14',
  close: 'M18 6L6 18M6 6l12 12',
  filter: 'M3 6h18M6 12h12M10 18h4',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 1 1 8 0v4',
  globe: 'M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20',
  card: 'M2 7h20v12H2zM2 11h20',
  receipt: 'M6 2h12v20l-3-2-3 2-3-2-3 2zM10 7h4M9 11h6M9 15h6',
  logout: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  sun: 'M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41',
  moon: 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z',
  mail: 'M4 4h16v16H4zM4 4l8 8 8-8',
  pin: 'M12 21s-8-7.58-8-13a8 8 0 0 1 16 0c0 5.42-8 13-8 13z',
  star: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z',
  gift: 'M20 12v10H4V12M2 7h20v5H2zM12 22V7M12 7H7.5a2.5 2.5 0 1 1 0-5C11 2 12 7 12 7zM12 7h4.5a2.5 2.5 0 1 0 0-5C13 2 12 7 12 7z',
};
const I = ({ path, size = 22, stroke = 2, style, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color || 'currentColor'} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={style}>
    <path d={IconPaths[path]}/>
  </svg>
);
const SvgUser = ({size=22}) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.user}/><circle cx="12" cy="7" r="4"/></svg>);
const SvgBell = ({size=22}) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.bell}/></svg>);
const SvgSearch = ({size=20}) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>);
const SvgQR = ({size=26}) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><line x1="14" y1="14" x2="14" y2="17"/><line x1="17" y1="14" x2="17" y2="21"/><line x1="20" y1="17" x2="20" y2="21"/><line x1="14" y1="20" x2="17" y2="20"/></svg>);

// ─── Typography ───
function Wordmark({ size = 22 }) {
  return (
    <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: size, letterSpacing: '-0.045em', lineHeight: 1, display: 'inline-flex', alignItems: 'baseline' }}>
      <span style={{ color: GP.ink }}>GYM</span><span style={{ color: GP.lime }}>PASS</span>
    </div>
  );
}
function Overline({ children, color = GP.lime, style }) {
  return <div style={{ fontFamily: GP.fMono, fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase', color, fontWeight: 500, ...style }}>{children}</div>;
}
function Display({ children, size = 42, color = GP.ink, style }) {
  return <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: size, letterSpacing: '-0.04em', lineHeight: 0.92, color, textTransform: 'uppercase', ...style }}>{children}</div>;
}
function SerifAccent({ children, size = 42, color = GP.lime }) {
  return <span style={{ fontFamily: GP.fSerif, fontStyle: 'italic', fontWeight: 400, fontSize: size * 0.82, color, letterSpacing: '-0.01em', textTransform: 'lowercase' }}>{children}</span>;
}
function Mono({ children, size = 10, color = GP.ink3, tracking = 0.2, style }) {
  return <span style={{ fontFamily: GP.fMono, fontSize: size, color, letterSpacing: `${tracking}em`, textTransform: 'uppercase', ...style }}>{children}</span>;
}

// ─── Buttons ───
function PillButton({ children, primary, fullWidth, onClick, style, disabled }) {
  const base = {
    padding: primary ? '17px 24px' : '13px 20px',
    borderRadius: 100,
    fontFamily: primary ? GP.fDisplay : GP.fBody,
    fontWeight: primary ? 900 : 600,
    fontStyle: primary ? 'italic' : 'normal',
    fontSize: primary ? 16 : 14,
    letterSpacing: primary ? '0.02em' : 0,
    textTransform: primary ? 'uppercase' : 'none',
    border: primary ? 'none' : `1px solid ${GP.border2}`,
    background: primary ? 'linear-gradient(180deg, #D5FF7E, #BBFB46)' : GP.bg3,
    color: primary ? '#0A0B0A' : GP.ink,
    boxShadow: primary ? '0 0 40px -8px rgba(187,251,70,0.5), inset 0 1px 0 rgba(255,255,255,0.3)' : 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.4 : 1,
    width: fullWidth ? '100%' : 'auto',
    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
    transition: 'transform 120ms ease, box-shadow 120ms ease',
    ...style,
  };
  return <button style={base} onClick={disabled ? undefined : onClick} onMouseDown={e => e.currentTarget.style.transform = 'scale(0.97)'} onMouseUp={e => e.currentTarget.style.transform = ''} onMouseLeave={e => e.currentTarget.style.transform = ''}>{children}</button>;
}

function IconBtn({ icon, onClick, badge, style }) {
  return (
    <button onClick={onClick} style={{ width: 38, height: 38, borderRadius: 100, background: GP.bg3, border: `1px solid ${GP.border2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GP.ink, position: 'relative', cursor: 'pointer', ...style }}>
      {icon}
      {badge && <div style={{ position: 'absolute', top: 7, right: 9, width: 8, height: 8, borderRadius: 100, background: GP.lime, boxShadow: `0 0 6px ${GP.lime}` }}/>}
    </button>
  );
}

// ─── Router / store ─────────
const RouteCtx = React.createContext(null);
const useRoute = () => React.useContext(RouteCtx);

function useAppStore() {
  const [state, setState] = React.useState(() => {
    try { return JSON.parse(localStorage.getItem('gp_state')) || defaultState(); } catch { return defaultState(); }
  });
  React.useEffect(() => { localStorage.setItem('gp_state', JSON.stringify(state)); }, [state]);
  const update = React.useCallback((p) => setState(s => ({ ...s, ...(typeof p === 'function' ? p(s) : p) })), []);
  return [state, update];
}
function defaultState() {
  return {
    route: { name: 'splash', params: {} },
    history: [],
    auth: { phone: '', name: '', authed: false },
    subscription: null, // { tier, visitsUsed, visitsTotal, startedAt, nextRenew }
    lastCheckIn: null,  // { gymId, at }
    filter: 'ALL',
    locale: 'en',
    toast: null,
  };
}

// ─── Phone frame ─────────
function Phone({ children, align = 'center', style, hideStatusBar = false }) {
  return (
    <div style={{ width: 390, height: 844, background: GP.bg, color: GP.ink, fontFamily: GP.fBody, position: 'relative', overflow: 'hidden', borderRadius: 44, ...style }}>
      {/* noise & warmth */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse 800px 400px at 15% 0%, rgba(187,251,70,0.06), transparent 60%)', pointerEvents: 'none' }}/>
      {!hideStatusBar && (
        <>
          {/* status bar */}
          <div style={{ height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 28px 0', fontFamily: '-apple-system, system-ui', fontSize: 15, fontWeight: 600, color: GP.ink, position: 'relative', zIndex: 30 }}>
            <span>9:41</span>
            <span style={{ fontSize: 13, display: 'flex', gap: 6, alignItems: 'center' }}>
              <svg width="17" height="11" viewBox="0 0 17 11" fill="currentColor"><rect x="0" y="7" width="3" height="4" rx="0.5"/><rect x="4.5" y="5" width="3" height="6" rx="0.5"/><rect x="9" y="2.5" width="3" height="8.5" rx="0.5"/><rect x="13.5" y="0" width="3" height="11" rx="0.5"/></svg>
              <svg width="24" height="11" viewBox="0 0 24 11" fill="none"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke="currentColor" opacity="0.4"/><rect x="2" y="2" width="17" height="7" rx="1" fill="currentColor"/><rect x="21" y="3.5" width="2" height="4" rx="0.5" fill="currentColor" opacity="0.4"/></svg>
            </span>
          </div>
        </>
      )}
      {/* notch always on top */}
      <div style={{ position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)', width: 120, height: 34, background: '#000', borderRadius: 20, zIndex: 40 }}/>
      <div style={{ position: 'relative', zIndex: 10, height: hideStatusBar ? '100%' : 'calc(100% - 54px)' }}>{children}</div>
    </div>
  );
}

// ─── Tab bar ─────────
function TabBar({ active, onTab, onCenter }) {
  const TABS = [
    { k: 'home',    label: 'Home',  icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg> },
    { k: 'gyms',    label: 'Gyms',  icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.map}/><circle cx="12" cy="10" r="3"/></svg> },
    { k: 'scan',    label: 'Scan',  icon: <SvgQR size={22}/> },
    { k: 'profile', label: 'You',   icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 22c0-4.4 3.6-8 8-8s8 3.6 8 8"/></svg> },
  ];
  const activeIdx = Math.max(0, TABS.findIndex(t => t.k === active));
  return (
    <div style={{
      position: 'absolute', bottom: 14, left: 14, right: 14,
      background: 'transparent',
      display: 'flex', alignItems: 'stretch',
      padding: '4px',
      zIndex: 40,
    }}>
      {/* Sliding indicator */}
      <div style={{
        position: 'absolute',
        top: 0,
        left: `calc(4px + ${activeIdx} * ((100% - 8px) / ${TABS.length}) + ((100% - 8px) / ${TABS.length} - 28px) / 2)`,
        width: 28, height: 2, borderRadius: 100,
        background: GP.lime,
        boxShadow: `0 0 10px ${GP.lime}cc`,
        transition: 'left 320ms cubic-bezier(0.7, 0, 0.2, 1)',
        pointerEvents: 'none',
      }}/>
      {TABS.map(t => {
        const on = t.k === active;
        const handler = t.k === 'scan' ? onCenter : () => onTab(t.k);
        return (
          <button
            key={t.k}
            onClick={handler}
            style={{
              background: 'transparent', border: 'none', flex: 1,
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
              padding: '10px 4px 8px',
              color: on ? GP.lime : GP.ink3,
              cursor: 'pointer',
              fontFamily: GP.fMono,
              position: 'relative',
              transition: 'color 220ms cubic-bezier(0.4, 0, 0.2, 1)',
            }}
          >
            <div style={{
              opacity: on ? 1 : 0.85,
              transform: on ? 'translateY(-1px)' : 'translateY(0)',
              transition: 'transform 260ms cubic-bezier(0.4,0,0.2,1)',
            }}>{t.icon}</div>
            <span style={{
              fontSize: 9,
              letterSpacing: '0.16em',
              textTransform: 'uppercase',
              fontWeight: on ? 600 : 500,
            }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ─── Top bar ─────────
function TopBar({ left, title, right }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 20px 12px' }}>
      <div style={{ width: 38, display: 'flex' }}>{left}</div>
      <Overline color={GP.ink3}>{title}</Overline>
      <div style={{ width: 38, display: 'flex', justifyContent: 'flex-end' }}>{right}</div>
    </div>
  );
}
function BackBtn({ onClick }) {
  return <IconBtn icon={<I path="back" size={18}/>} onClick={onClick}/>;
}

// ─── Tier pill ─────────
function TierChip({ tier, size = 10 }) {
  const t = TIERS[tier];
  if (!t) return null;
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 9px', borderRadius: 5, background: `${t.color}14`, color: t.color, fontFamily: GP.fMono, fontSize: size, fontWeight: 600, letterSpacing: '0.12em', border: `1px solid ${t.color}44`, textTransform: 'uppercase' }}>
      {t.glyph} {t.name}
    </div>
  );
}

// ─── Gym placeholder tile (line-art-ish over gradient) ─────────
function GymTile({ gym, size = 54, round = 12 }) {
  return (
    <div style={{ width: size, height: size, borderRadius: round, background: `linear-gradient(135deg, ${gym.color}22, #0A0B0A)`, border: `1px solid ${gym.color}33`, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ fontFamily: GP.fMono, fontSize: Math.max(9, size * 0.14), color: gym.color, letterSpacing: '0.1em', fontWeight: 600 }}>{gym.cat.slice(0,3)}</div>
    </div>
  );
}

// ─── Toast ─────────
function Toast({ msg }) {
  if (!msg) return null;
  return (
    <div style={{ position: 'absolute', top: 70, left: '50%', transform: 'translateX(-50%)', padding: '10px 16px', borderRadius: 100, background: GP.bg2, border: `1px solid ${GP.border2}`, color: GP.ink, fontFamily: GP.fMono, fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', zIndex: 90, boxShadow: '0 14px 40px rgba(0,0,0,0.5)' }}>
      {msg}
    </div>
  );
}

Object.assign(window, {
  GP, TIERS, GYMS, NOTIFS, IconPaths,
  I, SvgUser, SvgBell, SvgSearch, SvgQR,
  Wordmark, Overline, Display, SerifAccent, Mono,
  PillButton, IconBtn, Phone, TabBar, TopBar, BackBtn, TierChip, GymTile, Toast,
  RouteCtx, useRoute, useAppStore,
});
