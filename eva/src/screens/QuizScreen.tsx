import { useState } from 'react'
import { T, F, NeuralBackground, ButtonPrimary, QuizOption, ProgressBeads, useHex, rgba } from '../components/ds'
import { useTheme } from '../contexts/theme'

const OPTIONS = [
  { letter: 'A', text: 'The seas and dry land' },
  { letter: 'B', text: 'Light and darkness' },
  { letter: 'C', text: 'The sky and clouds' },
  { letter: 'D', text: 'Plants and trees' },
]

function GoldFleck({ x, y, delay }: { x: number; y: number; delay: number }) {
  return (
    <div style={{
      position: 'absolute', left: x, top: y, width: 5, height: 5, borderRadius: '50%',
      background: '#E8A33D', boxShadow: '0 0 10px #E8A33D',
      animation: `fleck-float 2s ease-in-out ${delay}ms infinite alternate`,
      pointerEvents: 'none',
    }} />
  )
}

export default function QuizScreen({ onBack, onFinish }: { onBack: () => void; onFinish: () => void }) {
  const [selected, setSelected] = useState<string | null>(null)
  const [checked, setChecked] = useState(false)
  const hex = useHex()
  const { isDark } = useTheme()
  const CORRECT = 'B'

  const frameToggleStyle = (active: boolean, accentColor: string) => ({
    fontFamily: F.mono, fontSize: 9, fontWeight: 700,
    letterSpacing: '0.10em', textTransform: 'uppercase' as const,
    padding: '5px 12px', borderRadius: 999, cursor: 'pointer',
    border: `1.5px solid ${active ? rgba(accentColor, 0.5) : rgba(isDark ? '#ffffff' : '#000000', 0.1)}`,
    background: active ? rgba(accentColor, 0.12) : 'transparent',
    color: active ? accentColor : T.ink3,
    boxShadow: active ? `0 0 14px ${rgba(accentColor, 0.25)}` : 'none',
  })

  return (
    <div style={{ flex: 1, background: T.canvas, display: 'flex', flexDirection: 'column', minHeight: 844, padding: '20px 20px 28px', position: 'relative' }}>
      <NeuralBackground variant={4} />

      {/* Top row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24, position: 'relative', zIndex: 2 }}>
        <button onClick={onBack} style={{ width: 44, height: 44, background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.ink2 }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
        <ProgressBeads total={5} completed={1} current={1} />
        <div style={{ width: 44 }} />
      </div>

      {/* Frame toggle */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 24, position: 'relative', zIndex: 2 }}>
        <button style={frameToggleStyle(!checked, hex.ember)} onClick={() => { setSelected(null); setChecked(false) }}>
          Frame A — Answering
        </button>
        <button style={frameToggleStyle(checked, hex.ok)} onClick={() => { setSelected('B'); setChecked(true) }}>
          Frame B — Feedback
        </button>
      </div>

      {/* Question label */}
      <div style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: hex.ember, textAlign: 'center', marginBottom: 12, position: 'relative', zIndex: 2, textShadow: `0 0 18px ${rgba(hex.ember, 0.55)}` }}>
        Question 2 of 5
      </div>

      {/* Question */}
      <div style={{ fontFamily: F.display, fontSize: 26, fontWeight: 600, color: T.ink, textAlign: 'center', lineHeight: 1.2, marginBottom: 30, position: 'relative', zIndex: 2, letterSpacing: '-0.01em' }}>
        What did God create on the first day?
      </div>

      {/* Options */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, flex: 1, position: 'relative', zIndex: 2 }}>
        {OPTIONS.map(opt => {
          let state: 'default' | 'selected' | 'correct' | 'incorrect' = 'default'
          if (checked) {
            if (opt.letter === CORRECT) state = 'correct'
            else if (opt.letter === selected && selected !== CORRECT) state = 'incorrect'
          } else if (selected === opt.letter) {
            state = 'selected'
          }
          const dimmed = checked && opt.letter !== CORRECT && opt.letter !== selected

          return (
            <div key={opt.letter} style={{ position: 'relative' }}>
              <QuizOption letter={opt.letter} text={opt.text} state={state} onClick={() => !checked && setSelected(opt.letter)} dimmed={dimmed} />
              {checked && opt.letter === CORRECT && (
                <>
                  <GoldFleck x={-10} y={12}  delay={0}   />
                  <GoldFleck x={-15} y={36}  delay={220} />
                  <GoldFleck x={356} y={8}   delay={110} />
                  <GoldFleck x={362} y={30}  delay={340} />
                </>
              )}
            </div>
          )
        })}
      </div>

      {/* Feedback banner */}
      {checked && (
        <div style={{
          marginTop: 14, padding: '12px 16px', borderRadius: 14,
          background: rgba(hex.ok, isDark ? 0.1 : 0.08),
          border: `1px solid ${rgba(hex.ok, 0.3)}`,
          display: 'flex', alignItems: 'center', gap: 10,
          boxShadow: `0 0 24px ${rgba(hex.ok, 0.18)}`,
          position: 'relative', zIndex: 2,
          animation: 'screen-in 250ms ease-out',
        }}>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: hex.ok, flexShrink: 0, boxShadow: `0 0 10px ${rgba(hex.ok, 0.8)}` }} />
          <span style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 500, color: T.ink }}>
            Exactly. Light — before anything else.
          </span>
        </div>
      )}

      {/* CTA */}
      <div style={{ marginTop: 14, position: 'relative', zIndex: 2 }}>
        <ButtonPrimary
          onClick={checked ? onFinish : () => selected && setChecked(true)}
          disabled={!checked && !selected}
        >
          {checked ? 'Next question' : 'Check answer'}
        </ButtonPrimary>
      </div>
    </div>
  )
}
