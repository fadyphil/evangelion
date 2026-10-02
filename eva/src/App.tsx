import { useState } from 'react'
import { useTheme } from './contexts/theme'
import { F, T, useHex } from './components/ds'
import LoginScreen from './screens/LoginScreen'
import HomeScreen from './screens/HomeScreen'
import ReadingEnScreen from './screens/ReadingEnScreen'
import ReadingArScreen from './screens/ReadingArScreen'
import QuizScreen from './screens/QuizScreen'
import ResultScreen from './screens/ResultScreen'
import ProfileScreen from './screens/ProfileScreen'
import SettingsScreen from './screens/SettingsScreen'

type Screen = 'login' | 'home' | 'reading-en' | 'reading-ar' | 'quiz' | 'result' | 'profile' | 'settings'

const SCREENS: { id: Screen; label: string }[] = [
  { id: 'login',      label: 'S1 Login'       },
  { id: 'home',       label: 'S2 Home'        },
  { id: 'reading-en', label: 'S3 EN Reading'  },
  { id: 'reading-ar', label: 'S4 AR Reading'  },
  { id: 'quiz',       label: 'S5 Quiz'        },
  { id: 'result',     label: 'S6 Result'      },
  { id: 'profile',    label: 'S7 Profile'     },
  { id: 'settings',   label: 'S8 Settings'    },
]

export default function App() {
  const [screen, setScreen] = useState<Screen>('login')
  const { isDark, toggle } = useTheme()
  const hex = useHex()

  const nav = (s: string) => setScreen(s as Screen)

  const screens: Record<Screen, React.ReactNode> = {
    'login':      <LoginScreen      onLogin={() => nav('home')} />,
    'home':       <HomeScreen       onNavigate={nav} />,
    'reading-en': <ReadingEnScreen  onBack={() => nav('home')} onBeginReflection={() => nav('quiz')} />,
    'reading-ar': <ReadingArScreen  onBack={() => nav('home')} onBeginReflection={() => nav('quiz')} />,
    'quiz':       <QuizScreen       onBack={() => nav('home')} onFinish={() => nav('result')} />,
    'result':     <ResultScreen     onReflectAgain={() => nav('quiz')} onBackToLibrary={() => nav('home')} />,
    'profile':    <ProfileScreen    onBack={() => nav('home')} onSettings={() => nav('settings')} />,
    'settings':   <SettingsScreen   onBack={() => nav('profile')} />,
  }

  return (
    <div style={{
      background: isDark ? '#030610' : '#E4E0FF',
      minHeight: '100vh',
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      padding: '16px 16px 32px', gap: 16,
      fontFamily: F.ui,
    }}>
      {/* Controls bar */}
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center',
        alignItems: 'center', maxWidth: 560, width: '100%',
      }}>
        {/* Theme toggle */}
        <button onClick={toggle} style={{
          fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.10em',
          textTransform: 'uppercase', padding: '6px 14px', borderRadius: 999, cursor: 'pointer',
          background: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)',
          border: `1.5px solid ${isDark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.12)'}`,
          color: isDark ? '#aaa8cc' : '#5a5480',
        }}>
          {isDark ? '☾ Dark' : '☀ Light'}
        </button>

        <div style={{ width: 1, height: 20, background: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)' }} />

        {SCREENS.map(s => (
          <button key={s.id} onClick={() => setScreen(s.id)} style={{
            fontFamily: F.mono, fontSize: 10, fontWeight: 700, letterSpacing: '0.08em',
            textTransform: 'uppercase', padding: '5px 12px', borderRadius: 999, cursor: 'pointer',
            border: screen === s.id
              ? `1.5px solid ${hex.ember}`
              : `1.5px solid ${isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}`,
            background: screen === s.id
              ? `${hex.ember}22`
              : 'transparent',
            color: screen === s.id ? hex.ember : (isDark ? '#6B6F94' : '#7A75A0'),
          }}>
            {s.label}
          </button>
        ))}
      </div>

      {/* Phone frame */}
      <div style={{
        width: 390,
        minHeight: 844,
        background: isDark ? '#05081A' : '#F0EEFF',
        borderRadius: 44,
        overflow: 'hidden',
        boxShadow: isDark
          ? '0 32px 80px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.05)'
          : '0 32px 80px rgba(18,14,40,0.25), 0 0 0 1px rgba(18,14,40,0.08)',
        position: 'relative',
        display: 'flex', flexDirection: 'column',
        animation: 'screen-in 300ms ease-out',
      }}>
        {screens[screen]}
      </div>
    </div>
  )
}
