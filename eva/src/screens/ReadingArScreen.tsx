import { T, F, NeuralBackground, ButtonPrimary, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

export default function ReadingArScreen({ onBack, onBeginReflection }: { onBack: () => void; onBeginReflection: () => void }) {
  const hex = useHex()
  const { isDark } = useTheme()

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, position: 'relative', direction: 'rtl' }}>
      <NeuralBackground variant={3} />

      {/* Arabic geometric band */}
      <div style={{
        height: 5, width: '100%', position: 'relative', zIndex: 2,
        backgroundImage: `repeating-linear-gradient(90deg, ${rgba('#B79CF0', isDark ? 0.3 : 0.2)} 0px, ${rgba('#B79CF0', isDark ? 0.3 : 0.2)} 2px, transparent 2px, transparent 18px)`,
      }} />

      {/* Top controls — RTL mirrored */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px 0', position: 'relative', zIndex: 2 }}>
        <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', fontFamily: F.display, fontSize: 17, fontWeight: 600, color: T.ink2 }}>Aa</button>
          <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: T.ink2 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>
          </button>
        </div>
        <button onClick={onBack} style={{ width: 44, height: 44, background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.ink2 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="9,18 15,12 9,6"/></svg>
        </button>
      </div>

      {/* Content */}
      <div className="no-scroll" style={{ flex: 1, overflowY: 'auto', padding: '28px 24px 130px', position: 'relative', zIndex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginBottom: 18, direction: 'rtl' }}>
          <span style={{ color: hex.ember, fontSize: 7 }}>✦</span>
          <span style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', color: T.ink3 }}>
            التكوين · الإصحاح ١ · ٤ دقائق
          </span>
          <span style={{ color: hex.ember, fontSize: 7 }}>✦</span>
        </div>

        <div style={{ fontFamily: F.display, fontSize: 32, fontWeight: 600, color: T.ink, textAlign: 'center', lineHeight: 1.15, marginBottom: 18 }}>
          البداية
        </div>

        <div style={{ width: 36, height: 1, background: isDark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.12)', margin: '0 auto 32px' }} />

        <div style={{ fontFamily: F.arabic, fontSize: 23, lineHeight: 2.2, color: T.ink, textAlign: 'right', direction: 'rtl', letterSpacing: 0 }}>
          <p>
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>١</sup>
            {' '}فِي الْبَدْءِ خَلَقَ اللهُ السَّمَاوَاتِ وَالأَرْضَ.{' '}
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٢</sup>
            {' '}وَكَانَتِ الأَرْضُ خَرِبَةً وَخَالِيَةً، وَعَلَى وَجْهِ الْغَمْرِ ظُلْمَةٌ، وَرُوحُ اللهِ يَرِفُّ عَلَى وَجْهِ الْمِيَاهِ.{' '}
            <span style={{ color: hex.ember, textShadow: `0 0 14px ${rgba(hex.ember, 0.65)}`, fontSize: 22 }}>۝</span>
          </p>
          <p style={{ marginTop: 20 }}>
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٣</sup>
            {' '}وَقَالَ اللهُ: «لِيَكُنْ نُورٌ»، فَكَانَ نُورٌ.{' '}
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٤</sup>
            {' '}وَرَأَى اللهُ النُّورَ أَنَّهُ حَسَنٌ. وَفَصَلَ اللهُ بَيْنَ النُّورِ وَالظُّلْمَةِ.{' '}
            <span style={{ color: hex.ember, textShadow: `0 0 14px ${rgba(hex.ember, 0.65)}`, fontSize: 22 }}>۝</span>
          </p>
          <p style={{ marginTop: 20 }}>
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٥</sup>
            {' '}وَدَعَا اللهُ النُّورَ نَهَارًا، وَالظُّلْمَةَ دَعَاهَا لَيْلًا. وَكَانَ مَسَاءٌ وَكَانَ صَبَاحٌ — يَوْمًا وَاحِدًا.{' '}
            <span style={{ color: hex.ember, textShadow: `0 0 14px ${rgba(hex.ember, 0.65)}`, fontSize: 22 }}>۝</span>
          </p>
          <p style={{ marginTop: 20 }}>
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٦</sup>
            {' '}وَقَالَ اللهُ: «لِيَكُنْ جَلَدٌ فِي وَسَطِ الْمِيَاهِ».{' '}
            <sup style={{ color: hex.ember, fontSize: 13, fontFamily: F.mono, fontWeight: 700, verticalAlign: 'super' }}>٧</sup>
            {' '}فَعَمِلَ اللهُ الْجَلَدَ، وَفَصَلَ بَيْنَ الْمِيَاهِ الَّتِي تَحْتَ الْجَلَدِ وَالْمِيَاهِ الَّتِي فَوْقَ الْجَلَدِ. وَكَانَ كَذَلِكَ.{' '}
            <span style={{ color: hex.ember, textShadow: `0 0 14px ${rgba(hex.ember, 0.65)}`, fontSize: 22 }}>۝</span>
          </p>
        </div>
      </div>

      {/* CTA */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, padding: '20px 24px 32px',
        background: isDark
          ? `linear-gradient(to bottom, transparent, ${rgba('#05081A', 0.95)} 40%)`
          : `linear-gradient(to bottom, transparent, ${rgba('#F0EEFF', 0.96)} 40%)`,
        zIndex: 2, direction: 'rtl',
      }}>
        <ButtonPrimary onClick={onBeginReflection}>ابدأ التأمل</ButtonPrimary>
        <div style={{ textAlign: 'center', marginTop: 8, fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.10em', color: T.ink3 }}>
          ٥ أسئلة · دقيقة تقريبًا
        </div>
      </div>
    </div>
  )
}
