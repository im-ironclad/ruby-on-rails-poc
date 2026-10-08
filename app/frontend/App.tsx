import { AppBar, Box, Container, CssBaseline, Tab, Tabs, ThemeProvider, Toolbar, Typography, createTheme } from '@mui/material'
import { Link as RouterLink, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { BondsDashboard } from './pages/bonds/BondsDashboard'
import { IssuerDetail } from './pages/bonds/IssuerDetail'
import { NewBondForm } from './pages/bonds/NewBondForm'
import { WatchlistPage } from './pages/watchlist/WatchlistPage'

const bondsTheme = createTheme({ palette: { mode: 'light', primary: { main: '#1d4f91' } } })
const watchlistTheme = createTheme({ palette: { mode: 'dark', background: { default: '#141414', paper: '#181818' }, error: { main: '#e50914' } } })

export function App() {
  const { pathname } = useLocation()
  const section = pathname.startsWith('/watchlist') ? 'watchlist' : 'bonds'

  return (
    <ThemeProvider theme={section === 'watchlist' ? watchlistTheme : bondsTheme}>
      <CssBaseline />
      <AppBar position="static" color={section === 'watchlist' ? 'transparent' : 'primary'} elevation={0}>
        <Toolbar>
          <Typography variant="h6" sx={{ mr: 4 }}>
            Debt Ledger
          </Typography>
          <Tabs value={section} textColor="inherit" indicatorColor="secondary">
            <Tab label="Bonds" value="bonds" component={RouterLink} to="/bonds" />
            <Tab label="Watchlist" value="watchlist" component={RouterLink} to="/watchlist" />
          </Tabs>
        </Toolbar>
      </AppBar>
      <Container maxWidth="xl">
        <Box sx={{ py: 4 }}>
          <Routes>
            <Route path="/" element={<Navigate to="/bonds" replace />} />
            <Route path="/bonds" element={<BondsDashboard />} />
            <Route path="/bonds/new" element={<NewBondForm />} />
            <Route path="/bonds/issuers/:id" element={<IssuerDetail />} />
            <Route path="/watchlist" element={<WatchlistPage />} />
            <Route path="*" element={<Typography>Page not found.</Typography>} />
          </Routes>
        </Box>
      </Container>
    </ThemeProvider>
  )
}
