// Evangelion DS — Neural Expressive Edition
import { useState, useEffect, useCallback, useRef } from 'react'
import { useTheme } from '../contexts/theme'

// ── CSS-var tokens (always current, no React needed) ──────────────────────
export const T = {
  canvas:     'var(--canvas)',
  surface:    'var(--surface)',
  raised:     'var(--raised)',
  ink:        'var(--ink)',
  ink2:       'var(--ink2)',
  ink3:       'var(--ink3)',
  line:       'var(--line)',
  ember:      'var(--ember)',
  emberDeep:  'var(--ember-deep)',
  onEmber:    'var(--on-ember)',
  ok:         'var(--ok)',
  err:        'var(--err)',
  // sticker palette (decorative only)
  sticker: {
    sky:      '#7CC4F0',
    lavender: '#B79CF0',
    pink:     '#F58FC4',
    coral:    '#F4836B',
    teal:     '#4EC9BD',
    leaf:     '#7FC96B',
    sun:      '#F5C84C',
  },
}

// Hex helpers (for things that need actual hex, not CSS vars)
export const HEX = {
  dark: {
    canvas: '#05081A', surface: '#0D1224', raised: '#141A2E',
    ink: '#EAE8F5', ink2: '#8A8FAD', ink3: '#424669', line: '#1C2238',
    ember: '#E8A33D', emberDeep: '#C77F1F', ok: '#4ECCA3', err: '#FF6B6B',
  },
  light: {
    canvas: '#F0EEFF', surface: '#FFFFFF', raised: '#E8E4FF',
    ink: '#120E28', ink2: '#5A5480', ink3: '#9B97B8', line: '#D5D0EF',
    ember: '#D4891A', emberDeep: '#B56C0C', ok: '#1A8C6A', err: '#D63B3B',
  },
}

export function useHex() {
  const { isDark } = useTheme()
  return isDark ? HEX.dark : HEX.light
}

// rgba helper using actual hex values
export const rgba = (hex: string, a: number) => {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r},${g},${b},${a})`
}

// Font families
export const F = {
  display:  "'Cormorant Garamond', Georgia, serif",
  scripture:"'EB Garamond', Georgia, serif",
  arabic:   "'Amiri', serif",
  ui:       "'DM Sans', sans-serif",
  mono:     "'Space Mono', monospace",
}

// ── Orb configurations per screen ─────────────────────────────────────────
const ORB_CONFIGS = [
  // 0 Login
  [
    { color: '#6C3FE8', size: 420, x: -100, y: -80,  float: 'orb-float-a', floatDur: 14, hueDur: 8,  hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 14 },
    { color: '#3B5BDB', size: 360, x: 180,  y: 260,  float: 'orb-float-b', floatDur: 18, hueDur: 11, hueDelay: -3,   hueDir: 'hue-cycle-rev', parallax: 9  },
    { color: '#C026D3', size: 280, x: 60,   y: 540,  float: 'orb-float-c', floatDur: 22, hueDur: 9,  hueDelay: -5,   hueDir: 'hue-cycle',     parallax: 6  },
  ],
  // 1 Home
  [
    { color: '#3B5BDB', size: 500, x: -160, y: -120, float: 'orb-float-a', floatDur: 16, hueDur: 10, hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 12 },
    { color: '#14B8A6', size: 320, x: 200,  y: 200,  float: 'orb-float-b', floatDur: 20, hueDur: 7,  hueDelay: -2,   hueDir: 'hue-cycle-rev', parallax: 8  },
    { color: '#6C3FE8', size: 260, x: -70,  y: 520,  float: 'orb-float-c', floatDur: 25, hueDur: 12, hueDelay: -4,   hueDir: 'hue-cycle',     parallax: 5  },
    { color: '#F59E0B', size: 200, x: 250,  y: 640,  float: 'orb-float-a', floatDur: 19, hueDur: 9,  hueDelay: -6,   hueDir: 'hue-cycle-rev', parallax: 3  },
  ],
  // 2 Reading EN
  [
    { color: '#3B5BDB', size: 380, x: -110, y: 40,   float: 'orb-float-a', floatDur: 20, hueDur: 14, hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 10 },
    { color: '#14B8A6', size: 300, x: 160,  y: 380,  float: 'orb-float-b', floatDur: 26, hueDur: 10, hueDelay: -4,   hueDir: 'hue-cycle-rev', parallax: 6  },
  ],
  // 3 Reading AR
  [
    { color: '#6C3FE8', size: 420, x: 40,   y: -90,  float: 'orb-float-b', floatDur: 18, hueDur: 9,  hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 11 },
    { color: '#06B6D4', size: 300, x: -80,  y: 360,  float: 'orb-float-c', floatDur: 22, hueDur: 13, hueDelay: -5,   hueDir: 'hue-cycle-rev', parallax: 7  },
  ],
  // 4 Quiz
  [
    { color: '#C026D3', size: 380, x: 110,  y: -130, float: 'orb-float-a', floatDur: 15, hueDur: 7,  hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 13 },
    { color: '#3B5BDB', size: 320, x: -110, y: 280,  float: 'orb-float-b', floatDur: 20, hueDur: 10, hueDelay: -2,   hueDir: 'hue-cycle-rev', parallax: 9  },
    { color: '#14B8A6', size: 220, x: 180,  y: 580,  float: 'orb-float-c', floatDur: 24, hueDur: 13, hueDelay: -5,   hueDir: 'hue-cycle',     parallax: 5  },
  ],
  // 5 Result
  [
    { color: '#F59E0B', size: 380, x: -70,  y: -90,  float: 'orb-float-a', floatDur: 17, hueDur: 8,  hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 12 },
    { color: '#F43F5E', size: 300, x: 150,  y: 240,  float: 'orb-float-b', floatDur: 21, hueDur: 11, hueDelay: -3,   hueDir: 'hue-cycle-rev', parallax: 8  },
    { color: '#6C3FE8', size: 250, x: -50,  y: 560,  float: 'orb-float-c', floatDur: 28, hueDur: 9,  hueDelay: -6,   hueDir: 'hue-cycle',     parallax: 4  },
  ],
  // 6 Profile
  [
    { color: '#14B8A6', size: 440, x: -110, y: -80,  float: 'orb-float-a', floatDur: 19, hueDur: 11, hueDelay: 0,    hueDir: 'hue-cycle-rev', parallax: 10 },
    { color: '#3B5BDB', size: 280, x: 190,  y: 380,  float: 'orb-float-b', floatDur: 23, hueDur: 8,  hueDelay: -4,   hueDir: 'hue-cycle',     parallax: 6  },
  ],
  // 7 Settings
  [
    { color: '#6C3FE8', size: 400, x: 70,   y: -110, float: 'orb-float-b', floatDur: 22, hueDur: 9,  hueDelay: 0,    hueDir: 'hue-cycle',     parallax: 11 },
    { color: '#06B6D4', size: 260, x: -70,  y: 440,  float: 'orb-float-a', floatDur: 18, hueDur: 12, hueDelay: -3,   hueDir: 'hue-cycle-rev', parallax: 6  },
  ],
]

// ── NeuralBackground ───────────────────────────────────────────────────────
export function NeuralBackground({ variant = 0 }: { variant?: number }) {
  const { isDark } = useTheme()
  const [mouse, setMouse] = useState({ x: 0, y: 0 })
  const rafRef = useRef<number>(0)
  const targetRef = useRef({ x: 0, y: 0 })
  const currentRef = useRef({ x: 0, y: 0 })

  // Smooth mouse tracking via lerp in RAF
  const onMouseMove = useCallback((e: MouseEvent) => {
    targetRef.current = {
      x: (e.clientX / window.innerWidth  - 0.5) * 32,
      y: (e.clientY / window.innerHeight - 0.5) * 24,
    }
  }, [])

  const onTouchMove = useCallback((e: TouchEvent) => {
    const t = e.touches[0]
    targetRef.current = {
      x: (t.clientX / window.innerWidth  - 0.5) * 32,
      y: (t.clientY / window.innerHeight - 0.5) * 24,
    }
  }, [])

  useEffect(() => {
    const lerp = (a: number, b: number, t: number) => a + (b - a) * t
    const tick = () => {
      currentRef.current.x = lerp(currentRef.current.x, targetRef.current.x, 0.05)
      currentRef.current.y = lerp(currentRef.current.y, targetRef.current.y, 0.05)
      setMouse({ x: currentRef.current.x, y: currentRef.current.y })
      rafRef.current = requestAnimationFrame(tick)
    }
    rafRef.current = requestAnimationFrame(tick)
    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('touchmove', onTouchMove, { passive: true })
    return () => {
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('touchmove', onTouchMove)
    }
  }, [onMouseMove, onTouchMove])

  const orbs = ORB_CONFIGS[variant % ORB_CONFIGS.length]
  const orbOpacity = isDark ? 0.55 : 0.16

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none', zIndex: 0 }}>

      {/* Aurora bands — top-to-bottom gradient that drifts */}
      <div style={{
        position: 'absolute', inset: 0,
        background: isDark
          ? `linear-gradient(180deg,
              rgba(108,63,232,0.22) 0%,
              rgba(6,182,212,0.14)  20%,
              rgba(20,184,166,0.10) 40%,
              rgba(243,67,94,0.12)  65%,
              rgba(59,91,219,0.20)  100%),
             linear-gradient(180deg,
              rgba(196,38,211,0.10) 0%,
              rgba(59,91,219,0.08)  50%,
              rgba(20,184,166,0.12) 100%)`
          : `linear-gradient(180deg,
              rgba(108,63,232,0.10) 0%,
              rgba(6,182,212,0.06)  25%,
              rgba(20,184,166,0.05) 50%,
              rgba(243,67,94,0.06)  75%,
              rgba(59,91,219,0.10)  100%),
             linear-gradient(180deg,
              rgba(196,38,211,0.04) 0%,
              rgba(59,91,219,0.04)  50%,
              rgba(20,184,166,0.05) 100%)`,
        backgroundSize: '100% 200%, 100% 200%',
        animation: 'aurora-drift 14s ease-in-out infinite',
        filter: 'blur(16px)',
      }} />

      {/* Floating color-cycling orbs */}
      {orbs.map((orb, i) => (
        <div key={i} style={{
          position: 'absolute',
          left: orb.x,
          top: orb.y,
          width: orb.size,
          height: orb.size,
          borderRadius: '50%',
          background: `radial-gradient(circle at 38% 38%, ${orb.color}, transparent 68%)`,
          opacity: orbOpacity,
          animation: `${orb.float} ${orb.floatDur}s ease-in-out infinite, ${orb.hueDir} ${orb.hueDur}s linear ${orb.hueDelay}s infinite`,
          willChange: 'transform, filter',
          transform: `translate(${mouse.x * (orb.parallax / 14)}px, ${mouse.y * (orb.parallax / 14)}px)`,
          transition: 'transform 0.9s cubic-bezier(0.16,1,0.3,1)',
        }} />
      ))}

      {/* Subtle noise grain */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")`,
        opacity: isDark ? 0.035 : 0.025,
      }} />
    </div>
  )
}

// ── ButtonPrimary ──────────────────────────────────────────────────────────
export function ButtonPrimary({ children, onClick, style, disabled }: {
  children: React.ReactNode; onClick?: () => void; style?: React.CSSProperties; disabled?: boolean
}) {
  const [pressed, setPressed] = useState(false)
  const hex = useHex()
  return (
    <button
      disabled={disabled}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onTouchStart={() => setPressed(true)}
      onTouchEnd={() => setPressed(false)}
      onClick={onClick}
      style={{
        fontFamily: F.ui, fontSize: 16, fontWeight: 700, letterSpacing: '0.01em',
        color: hex.ink,
        background: pressed ? hex.emberDeep : hex.ember,
        border: 'none', borderRadius: 14, height: 52, width: '100%',
        cursor: disabled ? 'not-allowed' : 'pointer',
        transition: 'background 180ms ease-out, box-shadow 180ms ease-out',
        position: 'relative', zIndex: 1,
        boxShadow: pressed ? 'none' : `0 0 28px ${rgba(hex.ember, 0.35)}, 0 4px 14px ${rgba(hex.ember, 0.25)}`,
        opacity: disabled ? 0.45 : 1,
        ...style,
      }}
    >{children}</button>
  )
}

// ── ButtonSecondary ────────────────────────────────────────────────────────
export function ButtonSecondary({ children, onClick, style }: {
  children: React.ReactNode; onClick?: () => void; style?: React.CSSProperties
}) {
  const hex = useHex()
  return (
    <button onClick={onClick} style={{
      fontFamily: F.ui, fontSize: 16, fontWeight: 600,
      color: T.ink, background: 'transparent',
      border: `1.5px solid ${rgba(hex.ink, 0.2)}`,
      borderRadius: 14, height: 52, width: '100%',
      cursor: 'pointer', position: 'relative', zIndex: 1,
      transition: 'border-color 180ms ease-out',
      ...style,
    }}>{children}</button>
  )
}

// ── ButtonText ─────────────────────────────────────────────────────────────
export function ButtonText({ children, onClick, color }: {
  children: React.ReactNode; onClick?: () => void; color?: string
}) {
  const hex = useHex()
  return (
    <button onClick={onClick} style={{
      fontFamily: F.ui, fontSize: 15, fontWeight: 500,
      color: color ?? T.ink, background: 'none', border: 'none',
      cursor: 'pointer', padding: 0, position: 'relative', zIndex: 1,
      display: 'inline-flex', alignItems: 'center', gap: 4,
    }}>
      {children}
      {!color && <span style={{ color: hex.ember, fontSize: 16, fontWeight: 700 }}>›</span>}
    </button>
  )
}

// ── Input ──────────────────────────────────────────────────────────────────
export function Input({ label, type = 'text', placeholder, error, rightIcon, focused }: {
  label: string; type?: string; placeholder?: string; error?: string
  rightIcon?: React.ReactNode; focused?: boolean
}) {
  const hex = useHex()
  const { isDark } = useTheme()
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, position: 'relative', zIndex: 1 }}>
      <label style={{
        fontFamily: F.mono, fontSize: 10, fontWeight: 700,
        letterSpacing: '0.12em', textTransform: 'uppercase', color: T.ink2,
      }}>{label}</label>
      <div style={{ position: 'relative' }}>
        <input
          type={type} placeholder={placeholder} readOnly
          style={{
            fontFamily: F.ui, fontSize: 15, fontWeight: 400,
            width: '100%', height: 52, borderRadius: 14, outline: 'none',
            border: `1.5px solid ${error ? hex.err : focused ? hex.ember : rgba(isDark ? '#ffffff' : '#000000', 0.1)}`,
            background: rgba(isDark ? '#ffffff' : '#000000', focused ? 0.06 : 0.03),
            padding: '0 44px 0 16px', color: T.ink, boxSizing: 'border-box',
            boxShadow: focused ? `0 0 0 3px ${rgba(hex.ember, 0.18)}, 0 0 20px ${rgba(hex.ember, 0.12)}` : 'none',
            backdropFilter: 'blur(8px)',
          }}
        />
        {rightIcon && (
          <div style={{ position: 'absolute', right: 14, top: '50%', transform: 'translateY(-50%)', color: T.ink3 }}>
            {rightIcon}
          </div>
        )}
      </div>
      {error && <span style={{ fontFamily: F.ui, fontSize: 12, fontWeight: 500, color: T.err }}>{error}</span>}
    </div>
  )
}

// ── CategoryChip ───────────────────────────────────────────────────────────
export function CategoryChip({ label, color, active }: { label: string; color: string; active?: boolean }) {
  const hex = useHex()
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 12px', borderRadius: 999,
      background: active ? rgba(hex.ember, 0.14) : rgba(color, 0.12),
      border: active ? `1.5px solid ${rgba(hex.ember, 0.45)}` : `1px solid ${rgba(color, 0.28)}`,
    }}>
      <div style={{
        width: 6, height: 6, borderRadius: '50%', flexShrink: 0,
        background: active ? hex.ember : color,
        boxShadow: active ? `0 0 6px ${rgba(hex.ember, 0.7)}` : `0 0 5px ${rgba(color, 0.6)}`,
      }} />
      <span style={{
        fontFamily: F.mono, fontSize: 10, fontWeight: 700,
        letterSpacing: '0.10em', textTransform: 'uppercase',
        color: active ? hex.ember : color,
      }}>{label}</span>
    </div>
  )
}

// ── ProgressBeads ──────────────────────────────────────────────────────────
export function ProgressBeads({ total = 5, completed = 0, current = 0 }: {
  total?: number; completed?: number; current?: number
}) {
  const hex = useHex()
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {Array.from({ length: total }).map((_, i) => {
        const done = i < completed
        const curr = i === current && !done
        return (
          <div key={i} style={{
            width: 10, height: 10, borderRadius: '50%',
            background: done ? hex.ember : 'transparent',
            border: curr ? `2px solid ${hex.ember}` : done ? 'none' : `1.5px solid ${rgba(hex.ink, 0.2)}`,
            boxShadow: done ? `0 0 10px ${rgba(hex.ember, 0.65)}` : curr ? `0 0 7px ${rgba(hex.ember, 0.45)}` : 'none',
          }} />
        )
      })}
    </div>
  )
}

// ── PassageCard ────────────────────────────────────────────────────────────
export function PassageCard({ category, categoryColor, reference, preview, progress, total, completed }: {
  category: string; categoryColor: string; reference: string; preview: string
  progress: number; total: number; completed?: boolean
}) {
  const hex = useHex()
  const { isDark } = useTheme()
  return (
    <div style={{
      background: rgba(isDark ? '#ffffff' : '#000000', isDark ? 0.05 : 0.03),
      backdropFilter: 'blur(20px)',
      borderRadius: 20, padding: 16,
      border: `1px solid ${rgba(isDark ? '#ffffff' : '#000000', 0.08)}`,
      display: 'flex', flexDirection: 'column', gap: 10,
      boxShadow: `0 4px 24px ${rgba('#000000', isDark ? 0.35 : 0.08)}`,
      position: 'relative', zIndex: 1,
    }}>
      <CategoryChip label={category} color={categoryColor} />
      <div style={{ fontFamily: F.display, fontSize: 20, fontWeight: 600, color: T.ink, lineHeight: 1.1 }}>
        {reference}
      </div>
      <div style={{ fontFamily: F.ui, fontSize: 13, fontWeight: 400, color: T.ink2, lineHeight: 1.45 }}>
        {preview}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
        <div style={{ height: 3, borderRadius: 999, background: rgba(hex.ink, 0.1), overflow: 'hidden' }}>
          <div style={{
            height: '100%', borderRadius: 999, width: `${(progress / total) * 100}%`,
            background: `linear-gradient(90deg, ${hex.ember}, ${rgba(T.sticker.sun, 1)})`,
            boxShadow: `0 0 8px ${rgba(hex.ember, 0.5)}`,
          }} />
        </div>
        <span style={{ fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.10em', textTransform: 'uppercase' }}>
          {completed
            ? <span style={{ color: hex.ok }}>Reflected ✓</span>
            : <span style={{ color: T.ink3 }}>{progress} of {total} reflected</span>
          }
        </span>
      </div>
    </div>
  )
}

// ── QuizOption ─────────────────────────────────────────────────────────────
type QuizState = 'default' | 'selected' | 'correct' | 'incorrect'

export function QuizOption({ letter, text, state = 'default', onClick, dimmed }: {
  letter: string; text: string; state?: QuizState; onClick?: () => void; dimmed?: boolean
}) {
  const hex = useHex()
  const { isDark } = useTheme()

  const accent = state === 'selected' ? hex.ember : state === 'correct' ? hex.ok : state === 'incorrect' ? hex.err : null
  const bg = accent ? rgba(accent, 0.09) : rgba(isDark ? '#ffffff' : '#000000', 0.03)
  const border = accent ?? rgba(isDark ? '#ffffff' : '#000000', 0.1)
  const badgeFill = (state === 'correct' || state === 'incorrect') ? accent! : 'transparent'
  const badgeBorder = accent ?? rgba(isDark ? '#ffffff' : '#000000', 0.18)

  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '0 16px', minHeight: 64, width: '100%',
      background: bg, borderRadius: 18,
      border: `1.5px solid ${border}`,
      cursor: 'pointer', textAlign: 'left',
      opacity: dimmed ? 0.48 : 1,
      transition: 'all 250ms cubic-bezier(0.16,1,0.3,1)',
      backdropFilter: 'blur(12px)',
      boxShadow: accent ? `0 0 22px ${rgba(accent, 0.22)}, inset 0 1px 0 ${rgba('#ffffff', 0.06)}` : `inset 0 1px 0 ${rgba('#ffffff', 0.04)}`,
      position: 'relative', zIndex: 1,
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: '50%', flexShrink: 0,
        background: badgeFill, border: `1.5px solid ${badgeBorder}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: accent && (state === 'correct' || state === 'incorrect') ? `0 0 12px ${rgba(accent, 0.55)}` : 'none',
        transition: 'all 250ms ease-out',
      }}>
        <span style={{ fontFamily: F.mono, fontSize: 12, fontWeight: 700, color: (state === 'correct' || state === 'incorrect') ? '#ffffff' : T.ink }}>
          {letter}
        </span>
      </div>
      <span style={{ fontFamily: F.ui, fontSize: 15, fontWeight: 400, color: T.ink, lineHeight: 1.4 }}>
        {text}
      </span>
    </button>
  )
}

// ── StatTile ───────────────────────────────────────────────────────────────
export function StatTile({ value, label }: { value: string; label: string }) {
  const { isDark } = useTheme()
  return (
    <div style={{
      flex: 1,
      background: rgba(isDark ? '#ffffff' : '#000000', isDark ? 0.05 : 0.03),
      backdropFilter: 'blur(16px)',
      borderRadius: 16, padding: '14px 10px',
      border: `1px solid ${rgba(isDark ? '#ffffff' : '#000000', 0.08)}`,
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
      position: 'relative', zIndex: 1,
    }}>
      <span style={{ fontFamily: F.display, fontSize: 24, fontWeight: 600, color: T.ink, lineHeight: 1 }}>{value}</span>
      <span style={{ fontFamily: F.mono, fontSize: 9, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: T.ink3, textAlign: 'center' }}>{label}</span>
    </div>
  )
}

// ── SettingsTile ───────────────────────────────────────────────────────────
export function SettingsTile({ title, children }: { title: string; children?: React.ReactNode }) {
  const { isDark } = useTheme()
  return (
    <div style={{
      background: rgba(isDark ? '#ffffff' : '#000000', isDark ? 0.05 : 0.03),
      backdropFilter: 'blur(12px)',
      borderRadius: 14, height: 56, padding: '0 16px',
      border: `1px solid ${rgba(isDark ? '#ffffff' : '#000000', 0.08)}`,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      position: 'relative', zIndex: 1,
    }}>
      <span style={{ fontFamily: F.ui, fontSize: 15, fontWeight: 500, color: T.ink }}>{title}</span>
      {children}
    </div>
  )
}

// ── TopBar ─────────────────────────────────────────────────────────────────
export function TopBar({ onProfileTap }: { onProfileTap?: () => void }) {
  const hex = useHex()
  const { isDark } = useTheme()
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '20px 20px 0', position: 'relative', zIndex: 2,
    }}>
      <span style={{ fontFamily: F.display, fontSize: 24, fontWeight: 600, color: T.ink, letterSpacing: '-0.01em' }}>
        Evangelion
      </span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        {/* Streak flame */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <svg width="14" height="18" viewBox="0 0 16 20" fill="none">
            <path d="M8 0C8 0 4 5 4 9C4 10.5 4.5 12 6 13C5.5 11 6.5 9 8 8C9 10 9.5 11 9 13C10.5 12 11 10.5 11 9C11 7 10 5 10 5C11.5 6.5 12 9 12 11C12 14.5 10.5 17 8 19C5.5 17 4 14.5 4 11C4 10.5 4.05 10 4.1 9.5C2.5 11 2 13 2 15C2 17.8 4.7 20 8 20C11.3 20 14 17.8 14 15C14 10 8 0 8 0Z" fill={hex.ember}/>
          </svg>
          <span style={{ fontFamily: F.mono, fontSize: 13, fontWeight: 700, color: T.ink }}>12</span>
        </div>
        {/* Avatar */}
        <button onClick={onProfileTap} style={{
          width: 32, height: 32, borderRadius: '50%', border: 'none', cursor: 'pointer',
          background: `linear-gradient(135deg, ${rgba('#14B8A6', 0.5)}, ${rgba('#3B5BDB', 0.5)})`,
          outline: `1.5px solid ${rgba('#14B8A6', isDark ? 0.4 : 0.6)}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <span style={{ fontFamily: F.ui, fontSize: 11, fontWeight: 700, color: isDark ? '#ffffff' : '#120E28' }}>MK</span>
        </button>
      </div>
    </div>
  )
}

// ── SealFAB ────────────────────────────────────────────────────────────────
export function SealFAB({ onNavigate }: { onNavigate?: (s: string) => void }) {
  const [open, setOpen] = useState(false)
  const hex = useHex()
  const { isDark } = useTheme()
  const items = [
    { label: 'Profile',  screen: 'profile'  },
    { label: 'Settings', screen: 'settings' },
    { label: 'Language', screen: null       },
  ]
  return (
    <div style={{ position: 'absolute', bottom: 28, right: 20, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8, zIndex: 10 }}>
      {open && items.map((item, i) => (
        <button key={item.label}
          onClick={() => { setOpen(false); item.screen && onNavigate?.(item.screen) }}
          style={{
            fontFamily: F.ui, fontSize: 14, fontWeight: 600, color: T.ink,
            background: rgba(isDark ? '#ffffff' : '#000000', 0.08),
            backdropFilter: 'blur(16px)',
            border: `1px solid ${rgba(isDark ? '#ffffff' : '#000000', 0.12)}`,
            borderRadius: 999, padding: '8px 18px', cursor: 'pointer',
            boxShadow: `0 8px 24px ${rgba('#000000', 0.35)}`,
            animation: `screen-in 200ms ease-out ${i * 40}ms both`,
          }}
        >{item.label}</button>
      ))}
      <button onClick={() => setOpen(o => !o)} style={{
        width: 56, height: 56, borderRadius: '50%', border: 'none', cursor: 'pointer',
        background: rgba(isDark ? '#ffffff' : '#000000', 0.08),
        backdropFilter: 'blur(20px)',
        outline: `1.5px solid ${rgba(hex.ember, 0.6)}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: `0 0 30px ${rgba(hex.ember, 0.3)}, 0 8px 20px ${rgba('#000000', 0.35)}`,
      }}>
        <span style={{ fontFamily: F.display, fontSize: 22, fontWeight: 600, color: T.ink, lineHeight: 1 }}>E</span>
      </button>
    </div>
  )
}
