import { useState } from 'react'
import { T, F, NeuralBackground, ButtonPrimary, ButtonText, CategoryChip, PassageCard, ProgressBeads, TopBar, SealFAB, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

const CATS = ['All', 'Gospels', 'Poetry', 'History', 'Prophets', 'Epistles']
const CAT_COLORS: Record<string, string> = {
  All: '#E8A33D', Gospels: '#F5C84C', Poetry: '#B79CF0',
  History: '#7CC4F0', Prophets: '#F4836B', Epistles: '#4EC9BD',
}

export default function HomeScreen({ onNavigate }: { onNavigate: (s: string) => void }) {
  const [cat, setCat] = useState('All')
  const hex = useHex()
  const { isDark } = useTheme()

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, overflowY: 'auto', position: 'relative' }}>
      <NeuralBackground variant={1} />

      <TopBar onProfileTap={() => onNavigate('profile')} />

      <div style={{ padding: '20px 20px 0', position: 'relative', zIndex: 1 }}>
        {/* Greeting */}
        <div style={{ marginBottom: 24 }}>
          <div style={{ fontFamily: F.display, fontSize: 30, fontWeight: 600, lineHeight: 1.1, letterSpacing: '-0.01em' }}>
            <span style={{ color: T.ink }}>Good evening, </span>
            <span style={{ color: hex.ember, textShadow: `0 0 24px ${rgba(hex.ember, 0.5)}` }}>Miriam</span>
          </div>
          <div style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 400, color: T.ink2, marginTop: 6 }}>
            Your streak is glowing. Keep it alive.
          </div>
        </div>

        {/* Hero panel */}
        <div
          onClick={() => onNavigate('reading-en')}
          style={{
            background: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.65)',
            backdropFilter: 'blur(24px)',
            borderRadius: 24, padding: '20px 20px 16px',
            border: `1px solid ${isDark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.9)'}`,
            marginBottom: 28, cursor: 'pointer',
            boxShadow: isDark ? '0 8px 40px rgba(0,0,0,0.4)' : '0 8px 32px rgba(18,14,40,0.12)',
          }}
        >
          <div style={{ fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: T.ink3, marginBottom: 12 }}>
            Continue Reading
          </div>

          <div style={{ display: 'flex', gap: 0, marginBottom: 10 }}>
            <span style={{
              fontFamily: F.display, fontSize: 76, fontWeight: 600, color: hex.ember,
              lineHeight: 0.78, float: 'left', marginRight: 6, marginTop: 4,
              textShadow: `0 0 32px ${rgba(hex.ember, 0.55)}`,
            }}>I</span>
            <span style={{ fontFamily: F.scripture, fontSize: 17, color: T.ink2, lineHeight: 1.7, paddingTop: 4 }}>
              n the beginning God created the heavens and the earth…
            </span>
          </div>

          <div style={{ clear: 'both', fontFamily: F.display, fontSize: 20, fontWeight: 600, color: T.ink, marginBottom: 14 }}>
            Genesis 1:1–31
          </div>

          <ProgressBeads total={5} completed={2} current={2} />

          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <div style={{ flex: 1 }}>
              <ButtonPrimary onClick={() => onNavigate('reading-en')}>Continue</ButtonPrimary>
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <ButtonText onClick={() => onNavigate('quiz')}>Start reflection</ButtonText>
            </div>
          </div>
        </div>

        {/* Section header */}
        <div style={{ fontFamily: F.ui, fontSize: 17, fontWeight: 700, color: T.ink, marginBottom: 12 }}>
          Explore the library
        </div>

        {/* Category chips */}
        <div className="no-scroll" style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 20, paddingBottom: 4, marginLeft: -20, paddingLeft: 20, paddingRight: 20 }}>
          {CATS.map(c => (
            <div key={c} onClick={() => setCat(c)} style={{ cursor: 'pointer', flexShrink: 0 }}>
              <CategoryChip label={c} color={CAT_COLORS[c] ?? hex.ember} active={cat === c} />
            </div>
          ))}
        </div>

        {/* Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, paddingBottom: 100 }}>
          <PassageCard category="Gospels" categoryColor="#F5C84C" reference="John 1" preview="In the beginning was the Word…" progress={3} total={5} />
          <PassageCard category="Poetry" categoryColor="#B79CF0" reference="Psalm 23" preview="The Lord is my shepherd…" progress={5} total={5} completed />
          <PassageCard category="Epistles" categoryColor="#4EC9BD" reference="Romans 8" preview="No condemnation for those…" progress={1} total={5} />
          <PassageCard category="Prophets" categoryColor="#F4836B" reference="Isaiah 40" preview="Comfort, comfort my people…" progress={0} total={5} />
        </div>
      </div>

      <SealFAB onNavigate={onNavigate} />
    </div>
  )
}
