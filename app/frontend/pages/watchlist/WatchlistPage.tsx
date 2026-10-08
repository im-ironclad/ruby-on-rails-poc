import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  CardMedia,
  Chip,
  Grid,
  IconButton,
  MenuItem,
  Rating as MuiRating,
  Select,
  Stack,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { api } from '../../api/client'
import { Loadable } from '../../components/Loadable'
import { useApi } from '../../lib/useApi'
import type { ListEntry, ListStatus, Rating, Show } from '../../types/watchlist'

const STATUS_LABELS: Record<ListStatus, string> = {
  want_to_watch: 'Want to watch',
  watching: 'Watching',
  watched: 'Watched',
}

type Filter = 'all' | 'my_list'

export function WatchlistPage() {
  const { state, setData } = useApi<Show[]>('/api/shows')
  const [filter, setFilter] = useState<Filter>('all')
  const [error, setError] = useState<string | null>(null)

  const setEntry = (showId: number, entry: ListEntry | null) =>
    setData((shows) => shows.map((show) => (show.id === showId ? { ...show, list_entry: entry } : show)))

  async function run(action: () => Promise<void>) {
    setError(null)
    try {
      await action()
    } catch (e) {
      setError((e as Error).message)
    }
  }

  const add = (show: Show) =>
    run(async () => setEntry(show.id, await api.post<ListEntry>('/api/list_entries', { list_entry: { show_id: show.id } })))

  const update = (entry: ListEntry, changes: Partial<Pick<ListEntry, 'status' | 'rating'>>) =>
    run(async () => setEntry(entry.show_id, await api.patch<ListEntry>(`/api/list_entries/${entry.id}`, { list_entry: changes })))

  const remove = (entry: ListEntry) =>
    run(async () => {
      await api.delete(`/api/list_entries/${entry.id}`)
      setEntry(entry.show_id, null)
    })

  return (
    <Stack spacing={3}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4">Watchlist</Typography>
        <ToggleButtonGroup size="small" exclusive value={filter} onChange={(_, value) => value && setFilter(value)}>
          <ToggleButton value="all">All shows</ToggleButton>
          <ToggleButton value="my_list">My List</ToggleButton>
        </ToggleButtonGroup>
      </Stack>
      {error && <Alert severity="error">{error}</Alert>}
      <Loadable state={state}>
        {(shows) => {
          const visible = filter === 'my_list' ? shows.filter((show) => show.list_entry) : shows
          if (visible.length === 0) return <Typography color="text.secondary">My List is empty. Add something from All shows.</Typography>
          return (
            <Grid container spacing={2}>
              {visible.map((show) => (
                <Grid key={show.id} size={{ xs: 6, sm: 4, md: 3, lg: 2.4 }}>
                  <ShowCard show={show} onAdd={add} onUpdate={update} onRemove={remove} />
                </Grid>
              ))}
            </Grid>
          )
        }}
      </Loadable>
    </Stack>
  )
}

interface ShowCardProps {
  show: Show
  onAdd: (show: Show) => void
  onUpdate: (entry: ListEntry, changes: Partial<Pick<ListEntry, 'status' | 'rating'>>) => void
  onRemove: (entry: ListEntry) => void
}

function ShowCard({ show, onAdd, onUpdate, onRemove }: ShowCardProps) {
  const entry = show.list_entry
  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column', bgcolor: '#181818' }} data-testid={`show-${show.id}`}>
      <Box sx={{ position: 'relative' }}>
        <CardMedia component="img" image={show.poster_url} alt={`${show.title} poster`} sx={{ aspectRatio: '2 / 3' }} />
        <Box sx={{ position: 'absolute', bottom: 0, left: 0, right: 0, p: 1, background: 'linear-gradient(transparent, rgba(0,0,0,0.9))' }}>
          <Typography variant="subtitle1" sx={{ fontWeight: 700, lineHeight: 1.2 }}>
            {show.title}
          </Typography>
        </Box>
      </Box>
      <CardContent sx={{ flexGrow: 1, pb: 1 }}>
        <Stack direction="row" spacing={0.5} sx={{ mb: 1 }}>
          <Chip size="small" label={show.kind} />
          <Chip size="small" label={show.genre} variant="outlined" />
          <Chip size="small" label={show.year} variant="outlined" />
        </Stack>
        <Typography variant="body2" color="text.secondary">
          {show.synopsis}
        </Typography>
      </CardContent>
      <CardActions sx={{ flexDirection: 'column', alignItems: 'stretch', gap: 1, px: 2, pb: 2 }}>
        {entry ? (
          <>
            <Select
              size="small"
              value={entry.status}
              onChange={(e) => onUpdate(entry, { status: e.target.value as ListStatus })}
              inputProps={{ 'aria-label': `${show.title} status` }}
            >
              {Object.entries(STATUS_LABELS).map(([value, label]) => (
                <MenuItem key={value} value={value}>
                  {label}
                </MenuItem>
              ))}
            </Select>
            <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
              <MuiRating
                name={`rating-${show.id}`}
                value={entry.rating}
                onChange={(_, value) => onUpdate(entry, { rating: value as Rating | null })}
              />
              <Tooltip title="Remove from My List">
                <IconButton size="small" aria-label={`Remove ${show.title}`} onClick={() => onRemove(entry)}>
                  ✕
                </IconButton>
              </Tooltip>
            </Stack>
          </>
        ) : (
          <Button variant="contained" color="error" onClick={() => onAdd(show)}>
            + My List
          </Button>
        )}
      </CardActions>
    </Card>
  )
}
