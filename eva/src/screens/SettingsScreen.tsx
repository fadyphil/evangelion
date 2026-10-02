import { useState } from 'react'
import { T, F, NeuralBackground, SettingsTile, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

export default function SettingsScreen({ onBack }: { onBack: () => void }) {
  const [theme, setTheme] = useState<'Light' | 'Dark' | 'System'>('Dark')
  const [fontSize, setFontSize] = useState(3)
  const [lang, setLang] = useState<'EN' | 'AR'>('EN')
  const [verseNums, setVerseNums] = useState(true)
  const [notifs, setNotifs] = useState(true)
  const hex = useHex()
  const { isDark } = useTheme()

  const Toggle = ({ on, onToggle }: { on: boolean; onToggle: () => void }) => (
    <button onClick={onToggle} style={{
      width: 44, height: 24, borderRadius: 999,
      background: on ? hex.ember : rgba(isDark ? '#ffffff' : '#000000', 0.12),
      display: 'flex', alignItems: 'center',
      padding: on ? '0 3px 0 0' : '0 0 0 3px',
      justifyContent: on ? 'flex-end' : 'flex-start',
      border: 'none', cursor: 'pointer', transition: 'all 220ms ease-out',
      boxShadow: on ? `0 0 14px ${rgba(hex.ember, 0.45)}` : 'none',
    }}>
      <div style={{ width: 18, height: 18, borderRadius: '50%', background: '#ffffff', boxShadow: '0 1px 4px rgba(0,0,0,0.25)' }} />
    </button>
  )

  const SectionLabel = ({ children }: { children: string }) => (
    <div style={{ fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: T.ink3, marginBottom: 10 }}>
      {children}
    </div>
  )

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, overflowY: 'auto', position: 'relative' }}>
      <NeuralBackground variant={7} />

      <div style={{ display: 'flex', alignItems: 'center', padding: '20px 20px 0', position: 'relative', zIndex: 2 }}>
        <button onClick={onBack} style={{ width: 44, height: 44, background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.ink2 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="15,18 9,12 15,6"/></svg>
        </button>
        <span style={{ fontFamily: F.display, fontSize: 26, fontWeight: 600, color: T.ink, marginLeft: 8, letterSpacing: '-0.01em' }}>Settings</span>
      </div>

      <div style={{ padding: '24px 24px 48px', display: 'flex', flexDirection: 'column', gap: 28, position: 'relative', zIndex: 1 }}>

        <div>
          <SectionLabel>Appearance</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <SettingsTile title="Theme">
              <div style={{ display: 'flex', background: rgba(isDark ? '#ffffff' : '#000000', 0.06), borderRadius: 8, overflow: 'hidden' }}>
                {(['Light', 'Dark', 'System'] as const).map(opt => (
                  <button key={opt} onClick={() => setTheme(opt)} style={{
                    fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.08em',
                    textTransform: 'uppercase', padding: '5px 10px', border: 'none', cursor: 'pointer',
                    background: theme === opt ? rgba(isDark ? '#ffffff' : '#000000', 0.1) : 'transparent',
                    color: theme === opt ? hex.ember : T.ink3,
                    transition: 'all 200ms ease-out',
                  }}>{opt}</button>
                ))}
              </div>
            </SettingsTile>
            <SettingsTile title="Font size">
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontFamily: F.ui, fontSize: 12, fontWeight: 400, color: T.ink3 }}>A</span>
                <input type="range" min={1} max={5} value={fontSize} onChange={e => setFontSize(+e.target.value)} style={{ accentColor: hex.ember, width: 80 }} />
                <span style={{ fontFamily: F.ui, fontSize: 17, fontWeight: 400, color: T.ink3 }}>A</span>
              </div>
            </SettingsTile>
          </div>
        </div>

        <div>
          <SectionLabel>Reading</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <SettingsTile title="Default language">
              <div style={{ display: 'flex', gap: 6 }}>
                {(['EN', 'AR'] as const).map(l => (
                  <button key={l} onClick={() => setLang(l)} style={{
                    fontFamily: F.ui, fontSize: 12, fontWeight: 600, padding: '4px 12px',
                    borderRadius: 999, border: `1.5px solid ${lang === l ? rgba(hex.ember, 0.5) : rgba(isDark ? '#ffffff' : '#000000', 0.12)}`,
                    background: lang === l ? rgba(hex.ember, 0.12) : 'transparent',
                    color: lang === l ? hex.ember : T.ink2, cursor: 'pointer',
                    boxShadow: lang === l ? `0 0 12px ${rgba(hex.ember, 0.25)}` : 'none',
                    transition: 'all 200ms ease-out',
                  }}>
                    {l === 'EN' ? 'English' : 'العربية'}
                  </button>
                ))}
              </div>
            </SettingsTile>
            <SettingsTile title="Verse numbers">
              <Toggle on={verseNums} onToggle={() => setVerseNums(v => !v)} />
            </SettingsTile>
          </div>
        </div>

        <div>
          <SectionLabel>Account</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {['Edit profile', 'Change password'].map(title => (
              <SettingsTile key={title} title={title}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={T.ink3 as string} strokeWidth="2"><polyline points="9,18 15,12 9,6"/></svg>
              </SettingsTile>
            ))}
            <SettingsTile title="Notifications">
              <Toggle on={notifs} onToggle={() => setNotifs(v => !v)} />
            </SettingsTile>
          </div>
        </div>

        <div>
          <SectionLabel>About</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <SettingsTile title="Version">
              <span style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.08em', color: T.ink3 }}>1.0.0 (42)</span>
            </SettingsTile>
            <SettingsTile title="Privacy policy">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={T.ink3 as string} strokeWidth="2"><polyline points="9,18 15,12 9,6"/></svg>
            </SettingsTile>
          </div>
        </div>

      </div>
    </div>
  )
}
