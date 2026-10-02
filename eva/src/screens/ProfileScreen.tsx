import { T, F, NeuralBackground, StatTile, SettingsTile, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

const JOURNEY = [
  { color: '#F5C84C', ref: 'John 1',    score: '4/5'  },
  { color: '#7FC96B', ref: 'Genesis 1', score: '5/5', perfect: true },
  { color: '#4EC9BD', ref: 'Romans 8',  score: '3/5'  },
  { color: '#B79CF0', ref: 'Psalm 23',  score: '5/5', perfect: true },
  { color: '#F4836B', ref: 'Isaiah 40', score: '4/5'  },
]

export default function ProfileScreen({ onBack, onSettings }: { onBack: () => void; onSettings: () => void }) {
  const hex = useHex()
  const { isDark } = useTheme()
  const glass = `rgba(${isDark ? '255,255,255' : '0,0,0'}, ${isDark ? 0.05 : 0.03})`
  const glassBorder = `rgba(${isDark ? '255,255,255' : '0,0,0'}, ${isDark ? 0.08 : 0.07})`

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, overflowY: 'auto', position: 'relative' }}>
      <NeuralBackground variant={6} />

      <div style={{ display: 'flex', alignItems: 'center', padding: '20px 20px 0', position: 'relative', zIndex: 2 }}>
        <button onClick={onBack} style={{ width: 44, height: 44, background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.ink2 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="15,18 9,12 15,6"/></svg>
        </button>
      </div>

      <div style={{ padding: '16px 24px 48px', position: 'relative', zIndex: 1 }}>
        {/* Avatar */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, marginBottom: 28 }}>
          <div style={{
            width: 76, height: 76, borderRadius: '50%',
            background: `linear-gradient(135deg, ${rgba('#14B8A6', isDark ? 0.5 : 0.35)}, ${rgba('#3B5BDB', isDark ? 0.5 : 0.35)})`,
            border: `2px solid ${rgba('#14B8A6', isDark ? 0.45 : 0.55)}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 0 36px ${rgba('#14B8A6', 0.28)}`,
          }}>
            <span style={{ fontFamily: F.ui, fontSize: 24, fontWeight: 700, color: isDark ? '#ffffff' : '#120E28' }}>MK</span>
          </div>
          <div style={{ fontFamily: F.display, fontSize: 28, fontWeight: 600, color: T.ink, letterSpacing: '-0.01em' }}>Miriam Khalil</div>
          <div style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: T.ink3 }}>@miriamk</div>
          <button style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 600, color: hex.ember, background: 'none', border: 'none', cursor: 'pointer' }}>Edit</button>
        </div>

        {/* Stats */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 32 }}>
          <StatTile value="12" label="Streak" />
          <StatTile value="14" label="Passages" />
          <StatTile value="82%" label="Avg score" />
        </div>

        {/* Journey */}
        <div style={{ fontFamily: F.ui, fontSize: 16, fontWeight: 700, color: T.ink, marginBottom: 14 }}>Journey</div>
        <div style={{
          display: 'flex', flexDirection: 'column', marginBottom: 32,
          background: glass, backdropFilter: 'blur(16px)',
          borderRadius: 20, border: `1px solid ${glassBorder}`, padding: '0 20px',
        }}>
          {JOURNEY.map((item, i) => (
            <div key={i}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '15px 0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 10, height: 10, borderRadius: '50%', background: item.color, boxShadow: `0 0 10px ${rgba(item.color, isDark ? 0.7 : 0.5)}`, flexShrink: 0 }} />
                  <span style={{ fontFamily: F.display, fontSize: 19, fontWeight: 600, color: T.ink }}>{item.ref}</span>
                </div>
                <span style={{ fontFamily: F.mono, fontSize: 12, fontWeight: 700, color: item.perfect ? hex.ok : T.ink2 }}>{item.score}</span>
              </div>
              {i < JOURNEY.length - 1 && <div style={{ height: 1, background: glassBorder }} />}
            </div>
          ))}
        </div>

        {/* Settings */}
        <div style={{ fontFamily: F.ui, fontSize: 16, fontWeight: 700, color: T.ink, marginBottom: 14 }}>Settings</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 28 }}>
          <SettingsTile title="Theme">
            <div style={{ display: 'flex', background: rgba(isDark ? '#ffffff' : '#000000', 0.06), borderRadius: 8, overflow: 'hidden' }}>
              {['Light', 'Dark', 'System'].map((opt, i) => (
                <button key={opt} style={{
                  fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.08em',
                  textTransform: 'uppercase', padding: '5px 10px', border: 'none', cursor: 'pointer',
                  background: i === 1 ? rgba(isDark ? '#ffffff' : '#000000', 0.1) : 'transparent',
                  color: i === 1 ? hex.ember : T.ink3,
                }}>{opt}</button>
              ))}
            </div>
          </SettingsTile>
          <SettingsTile title="Font size">
            <input type="range" min={1} max={5} defaultValue={3} style={{ accentColor: hex.ember, width: 100 }} />
          </SettingsTile>
          <SettingsTile title="Language">
            <span style={{ fontFamily: F.ui, fontSize: 13, fontWeight: 500, color: T.ink2 }}>English / العربية</span>
          </SettingsTile>
          <SettingsTile title="Notifications">
            <div style={{ width: 44, height: 24, borderRadius: 999, background: hex.ember, display: 'flex', alignItems: 'center', paddingRight: 3, justifyContent: 'flex-end', cursor: 'pointer', boxShadow: `0 0 14px ${rgba(hex.ember, 0.45)}` }}>
              <div style={{ width: 18, height: 18, borderRadius: '50%', background: '#ffffff' }} />
            </div>
          </SettingsTile>
        </div>

        <button style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 600, color: hex.err, background: 'none', border: 'none', cursor: 'pointer' }}>
          Sign out
        </button>
      </div>
    </div>
  )
}
