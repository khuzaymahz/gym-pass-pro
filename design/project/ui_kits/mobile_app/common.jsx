// GymPass UI Kit screens. All components self-contained, dark theme.
// Every screen is ~390×844 (iPhone 13/14 content area). Export to window at end.

const GP = {
  // style primitives for inline use where CSS variables can't reach
  bg: '#0A0B0A', bg2: '#171A19', bg3: '#1E2221',
  lime: '#BBFB46', lime2: '#D5FF7E',
  ink: '#F4F4F0', ink2: '#CACBC2', ink3: '#8E8F86', ink4: '#5A5B54',
  border: 'rgba(255,255,255,0.08)', border2: 'rgba(255,255,255,0.14)',
  fDisplay: "'Archivo', system-ui, sans-serif",
  fBody: "'Inter', system-ui, sans-serif",
  fMono: "'JetBrains Mono', monospace",
  fSerif: "'Instrument Serif', serif",
};

// ─── Icons (inline SVG, stroke currentColor, 2px) ───
const Icon = ({ d, fill, size = 22, stroke = 2 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill || 'none'} stroke={fill ? 'none' : 'currentColor'} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round">
    <path d={d} />
  </svg>
);
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
};
const SvgUser = () => (<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.user}/><circle cx="12" cy="7" r="4"/></svg>);
const SvgBell = () => (<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.bell}/></svg>);
const SvgSearch = () => (<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>);
const SvgQR = ({size=26}) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><line x1="14" y1="14" x2="14" y2="17"/><line x1="17" y1="14" x2="17" y2="21"/><line x1="20" y1="17" x2="20" y2="21"/><line x1="14" y1="20" x2="17" y2="20"/></svg>);

// ─── Shared chrome ───

function Wordmark({ size = 22 }) {
  return (
    <div style={{
      fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic',
      fontSize: size, letterSpacing: '-0.045em', lineHeight: 1,
      display: 'inline-flex', alignItems: 'baseline',
    }}>
      <span style={{ color: GP.ink }}>GYM</span>
      <span style={{ color: GP.lime }}>PASS</span>
    </div>
  );
}

function Overline({ children, color = GP.lime }) {
  return <div style={{ fontFamily: GP.fMono, fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase', color, fontWeight: 500 }}>{children}</div>;
}

function Display({ children, size = 42, color = GP.ink }) {
  return <div style={{ fontFamily: GP.fDisplay, fontWeight: 900, fontStyle: 'italic', fontSize: size, letterSpacing: '-0.04em', lineHeight: 0.92, color, textTransform: 'uppercase' }}>{children}</div>;
}
function SerifAccent({ children, size = 42 }) {
  return <span style={{ fontFamily: GP.fSerif, fontStyle: 'italic', fontWeight: 400, fontSize: size * 0.82, color: GP.lime, letterSpacing: '-0.01em', textTransform: 'lowercase' }}>{children}</span>;
}

function PillButton({ children, primary, sub, fullWidth, style }) {
  const base = {
    padding: primary ? '18px 24px' : '13px 20px',
    borderRadius: 100,
    fontFamily: primary ? GP.fDisplay : GP.fBody,
    fontWeight: primary ? 900 : 600,
    fontStyle: primary ? 'italic' : 'normal',
    fontSize: primary ? 17 : 14,
    letterSpacing: primary ? '0.02em' : 0,
    textTransform: primary ? 'uppercase' : 'none',
    border: primary ? 'none' : `1px solid ${GP.border2}`,
    background: primary ? 'linear-gradient(180deg, #D5FF7E, #BBFB46)' : GP.bg3,
    color: primary ? '#0A0B0A' : GP.ink,
    boxShadow: primary ? '0 0 40px -8px rgba(187,251,70,0.5), inset 0 1px 0 rgba(255,255,255,0.3)' : 'none',
    cursor: 'pointer',
    width: fullWidth ? '100%' : 'auto',
    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
    ...style,
  };
  return <button style={base}>{children}</button>;
}

function TabBar({ active = 'home' }) {
  const tab = (k, icon, label) => {
    const on = k === active;
    return (
      <div key={k} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '8px 4px', color: on ? GP.lime : GP.ink4 }}>
        {icon}
        <span style={{ fontFamily: GP.fMono, fontSize: 9, letterSpacing: '0.1em', textTransform: 'uppercase' }}>{label}</span>
      </div>
    );
  };
  return (
    <div style={{
      position: 'absolute', bottom: 34, left: 12, right: 12,
      background: 'rgba(14,14,12,0.92)', backdropFilter: 'blur(20px)',
      border: `1px solid ${GP.border2}`, borderRadius: 22,
      display: 'flex', alignItems: 'center', padding: '6px 4px', zIndex: 40,
    }}>
      {tab('home', <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>, 'Explore')}
      {tab('map', <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={IconPaths.map}/><circle cx="12" cy="10" r="3"/></svg>, 'Map')}
      <div style={{ flex: 0.9, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 56, height: 56, borderRadius: 100, background: 'linear-gradient(180deg, #D5FF7E, #BBFB46)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#0A0B0A', boxShadow: '0 0 30px -6px rgba(187,251,70,0.55)', marginTop: -20 }}>
          <SvgQR size={28}/>
        </div>
      </div>
      {tab('profile', <SvgUser/>, 'Profile')}
    </div>
  );
}

function Screen({ children, style }) {
  return (
    <div style={{
      width: 390, height: 844, background: GP.bg, color: GP.ink,
      fontFamily: GP.fBody, position: 'relative', overflow: 'hidden',
      ...style,
    }}>
      {/* radial warmth */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse 800px 400px at 15% 0%, rgba(187,251,70,0.05), transparent 60%)', pointerEvents: 'none' }}/>
      {/* status bar spacer */}
      <div style={{ height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 22px 0', fontFamily: '-apple-system, system-ui', fontSize: 15, fontWeight: 600, color: GP.ink, position: 'relative', zIndex: 30 }}>
        <span>9:41</span>
        <span style={{ fontSize: 13, display: 'flex', gap: 6, alignItems: 'center' }}>
          <svg width="17" height="11" viewBox="0 0 17 11" fill="currentColor"><rect x="0" y="7" width="3" height="4" rx="0.5"/><rect x="4.5" y="5" width="3" height="6" rx="0.5"/><rect x="9" y="2.5" width="3" height="8.5" rx="0.5"/><rect x="13.5" y="0" width="3" height="11" rx="0.5"/></svg>
          <svg width="24" height="11" viewBox="0 0 24 11" fill="none"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke="currentColor" opacity="0.4"/><rect x="2" y="2" width="17" height="7" rx="1" fill="currentColor"/><rect x="21" y="3.5" width="2" height="4" rx="0.5" fill="currentColor" opacity="0.4"/></svg>
        </span>
      </div>
      <div style={{ position: 'relative', zIndex: 10, height: 'calc(100% - 54px)' }}>{children}</div>
    </div>
  );
}

Object.assign(window, { GP, Wordmark, Overline, Display, SerifAccent, PillButton, TabBar, Screen, SvgUser, SvgBell, SvgSearch, SvgQR, IconPaths });
