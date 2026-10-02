import { T, F, NeuralBackground, ButtonPrimary, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

export default function ReadingEnScreen({ onBack, onBeginReflection }: { onBack: () => void; onBeginReflection: () => void }) {
  const hex = useHex()
  const { isDark } = useTheme()

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, position: 'relative' }}>
      <NeuralBackground variant={2} />

      {/* Top controls */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 20px 0', position: 'relative', zIndex: 2 }}>
        <button onClick={onBack} style={{ width: 44, height: 44, background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.ink2 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="15,18 9,12 15,6"/></svg>
        </button>
        <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', fontFamily: F.display, fontSize: 17, fontWeight: 600, color: T.ink2, letterSpacing: '0.02em' }}>Aa</button>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: T.ink2 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="no-scroll" style={{ flex: 1, overflowY: 'auto', padding: '28px 24px 130px', position: 'relative', zIndex: 1 }}>
        {/* Metadata */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginBottom: 18 }}>
          <span style={{ color: hex.ember, fontSize: 7 }}>✦</span>
          <span style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: T.ink3 }}>
            Genesis · Chapter 1 · 4 min
          </span>
          <span style={{ color: hex.ember, fontSize: 7 }}>✦</span>
        </div>

        {/* Title */}
        <div style={{ fontFamily: F.display, fontSize: 34, fontWeight: 600, color: T.ink, textAlign: 'center', lineHeight: 1.05, marginBottom: 18, letterSpacing: '-0.01em' }}>
          The Beginning
        </div>

        {/* Divider */}
        <div style={{ width: 36, height: 1, background: isDark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.12)', margin: '0 auto 30px' }} />

        {/* Scripture */}
        <div style={{ fontFamily: F.scripture, fontSize: 19, lineHeight: 1.85, color: T.ink }}>
          <p>
            <span style={{ fontFamily: F.display, fontSize: 82, fontWeight: 600, color: hex.ember, lineHeight: 0.78, float: 'left', marginRight: 6, marginTop: 6, textShadow: `0 0 36px ${rgba(hex.ember, 0.5)}` }}>I</span>
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>1</sup>
            {' '}n the beginning God created the heavens and the earth.{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>2</sup>
            {' '}Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters.
          </p>
          <div style={{ clear: 'both' }} />
          <p style={{ marginTop: 22 }}>
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>3</sup>
            {' '}And God said, "Let there be light," and there was light.{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>4</sup>
            {' '}God saw that the light was good, and he separated the light from the darkness.{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>5</sup>
            {' '}God called the light "day," and the darkness he called "night." And there was evening, and there was morning — the first day.
          </p>
          <p style={{ marginTop: 22 }}>
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>6</sup>
            {' '}And God said, "Let there be a vault between the waters to separate water from water."{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>7</sup>
            {' '}So God made the vault and separated the water under the vault from the water above it. And it was so.{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>8</sup>
            {' '}God called the vault "sky." And there was evening, and there was morning — the second day.
          </p>
          <p style={{ marginTop: 22 }}>
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>9</sup>
            {' '}And God said, "Let the water under the sky be gathered to one place, and let dry ground appear." And it was so.{' '}
            <sup style={{ color: hex.ember, fontSize: 11, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>10</sup>
            {' '}God called the dry ground "land," and the gathered waters he called "seas." And God saw that it was good.
          </p>
        </div>
      </div>

      {/* Sticky CTA */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, padding: '20px 24px 32px',
        background: isDark
          ? `linear-gradient(to bottom, transparent, ${rgba('#05081A', 0.95)} 40%)`
          : `linear-gradient(to bottom, transparent, ${rgba('#F0EEFF', 0.96)} 40%)`,
        zIndex: 2,
      }}>
        <ButtonPrimary onClick={onBeginReflection}>Begin reflection</ButtonPrimary>
        <div style={{ textAlign: 'center', marginTop: 8, fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: T.ink3 }}>
          5 questions · about a minute
        </div>
      </div>
    </div>
  )
}
