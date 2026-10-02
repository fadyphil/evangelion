import { T, F, NeuralBackground, ButtonPrimary, ButtonSecondary, StatTile, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

function SunBurst({ emberHex }: { emberHex: string }) {
  return (
    <svg width="100" height="100" viewBox="0 0 100 100" fill="none">
      {Array.from({ length: 14 }).map((_, i) => {
        const a = (i * (360 / 14) * Math.PI) / 180
        const inner = 26, outer = i % 2 === 0 ? 46 : 39
        return <line key={i}
          x1={50 + inner * Math.cos(a)} y1={50 + inner * Math.sin(a)}
          x2={50 + outer * Math.cos(a)} y2={50 + outer * Math.sin(a)}
          stroke="#F5C84C" strokeWidth={i % 2 === 0 ? 2.5 : 1.5} strokeLinecap="round"
        />
      })}
      <circle cx="50" cy="50" r="24" fill="#F5C84C" opacity="0.9"/>
      <circle cx="50" cy="50" r="18" fill="#F5C84C" opacity="0.6"/>
      <circle cx="50" cy="50" r="30" fill={rgba('#F5C84C', 0.12)}/>
      {/* Flecks */}
      <circle cx="28" cy="18" r="2.5" fill={emberHex} opacity="0.9"/>
      <circle cx="72" cy="16" r="2"   fill={emberHex} opacity="0.7"/>
      <circle cx="80" cy="60" r="2"   fill={emberHex} opacity="0.8"/>
      <circle cx="16" cy="64" r="2.5" fill={emberHex} opacity="0.6"/>
      <circle cx="64" cy="82" r="2"   fill={emberHex} opacity="0.7"/>
    </svg>
  )
}

export default function ResultScreen({ onReflectAgain, onBackToLibrary }: { onReflectAgain: () => void; onBackToLibrary: () => void }) {
  const hex = useHex()
  const { isDark } = useTheme()

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '52px 24px 36px', minHeight: 844, position: 'relative' }}>
      <NeuralBackground variant={5} />

      {/* Burst */}
      <div style={{ marginBottom: 22, position: 'relative', zIndex: 1, filter: `drop-shadow(0 0 36px ${rgba('#F5C84C', 0.55)})` }}>
        <SunBurst emberHex={hex.ember} />
      </div>

      {/* Score */}
      <div style={{ position: 'relative', zIndex: 1, marginBottom: 14, lineHeight: 1 }}>
        <span style={{ fontFamily: F.display, fontSize: 68, fontWeight: 600, color: T.ink, letterSpacing: '-0.02em' }}>4</span>
        <span style={{ fontFamily: F.display, fontSize: 42, fontWeight: 600, color: T.ink3 }}>/5</span>
      </div>

      {/* Message */}
      <p style={{ fontFamily: F.ui, fontSize: 16, fontWeight: 400, color: T.ink2, textAlign: 'center', marginBottom: 24, lineHeight: 1.55, maxWidth: 260, position: 'relative', zIndex: 1 }}>
        So close. One more read and you've got it.
      </p>

      {/* Streak pill */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        background: rgba(hex.ember, isDark ? 0.12 : 0.1),
        border: `1px solid ${rgba(hex.ember, 0.28)}`,
        borderRadius: 999, padding: '8px 18px', marginBottom: 32,
        boxShadow: `0 0 24px ${rgba(hex.ember, 0.22)}`,
        position: 'relative', zIndex: 1,
      }}>
        <svg width="14" height="18" viewBox="0 0 16 20" fill="none">
          <path d="M8 0C8 0 4 5 4 9C4 10.5 4.5 12 6 13C5.5 11 6.5 9 8 8C9 10 9.5 11 9 13C10.5 12 11 10.5 11 9C11 7 10 5 10 5C11.5 6.5 12 9 12 11C12 14.5 10.5 17 8 19C5.5 17 4 14.5 4 11C4 10.5 4.05 10 4.1 9.5C2.5 11 2 13 2 15C2 17.8 4.7 20 8 20C11.3 20 14 17.8 14 15C14 10 8 0 8 0Z" fill={hex.ember}/>
        </svg>
        <span style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 600, color: T.ink }}>Day 12 — your longest yet</span>
      </div>

      {/* Stats */}
      <div style={{ display: 'flex', gap: 10, width: '100%', marginBottom: 32, position: 'relative', zIndex: 1 }}>
        <StatTile value="14" label="Read" />
        <StatTile value="9" label="Reflected" />
        <StatTile value="5/5" label="Best" />
      </div>

      {/* Buttons */}
      <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 12, position: 'relative', zIndex: 1 }}>
        <ButtonPrimary onClick={onReflectAgain}>Reflect again</ButtonPrimary>
        <ButtonSecondary onClick={onBackToLibrary}>Back to library</ButtonSecondary>
      </div>
    </div>
  )
}
