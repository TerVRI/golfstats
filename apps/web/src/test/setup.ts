import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  }),
  usePathname: () => '/',
  useSearchParams: () => new URLSearchParams(),
  use: (promise: Promise<any>) => promise,
}))

// Mock next/image
vi.mock('next/image', () => ({
  default: (props: any) => {
    const React = require('react');
    return React.createElement('img', props);
  },
}))

// Mock react-leaflet
vi.mock('react-leaflet', () => {
  const React = require('react');
  return {
    MapContainer: ({ children }: any) => React.createElement('div', { 'data-testid': 'map-container' }, children),
    TileLayer: () => React.createElement('div', { 'data-testid': 'tile-layer' }),
    Marker: ({ children }: any) => React.createElement('div', { 'data-testid': 'marker' }, children),
    Popup: ({ children }: any) => React.createElement('div', { 'data-testid': 'popup' }, children),
    Circle: () => React.createElement('div', { 'data-testid': 'circle' }),
    useMap: () => ({
      setView: vi.fn(),
    }),
  };
})

// Mock leaflet
vi.mock('leaflet', () => ({
  default: {
    Icon: {
      Default: {
        prototype: {},
        mergeOptions: vi.fn(),
      },
    },
  },
}))

// Mock Supabase client
vi.mock('@/lib/supabase/client', () => ({
  createClient: () => ({
    auth: {
      getUser: vi.fn().mockResolvedValue({ data: { user: null }, error: null }),
      signInWithOAuth: vi.fn(),
      signOut: vi.fn(),
    },
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      insert: vi.fn().mockReturnThis(),
      update: vi.fn().mockReturnThis(),
      delete: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({ data: null, error: null }),
    })),
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn().mockResolvedValue({ data: { path: 'test.jpg' }, error: null }),
        getPublicUrl: vi.fn(() => ({ data: { publicUrl: 'https://example.com/test.jpg' } })),
      })),
    },
  }),
}))

// Mock useUser hook
vi.mock('@/hooks/useUser', () => ({
  useUser: () => ({
    user: { id: 'test-user-id' },
    loading: false,
  }),
}))
