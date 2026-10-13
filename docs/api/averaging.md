# Averaging

## Average Over Space

Aggregate cell-level quantities into grid boxes (or other spatial domains) via
polygon-intersection weights.

```{eval-rst}
.. automodule:: pyanimalprocessing.average_over_space
   :members:
   :undoc-members: False
   :show-inheritance:
```

## Average Over Time

Average spatially-aggregated properties over developmental-time windows into
`TIME_AVERAGE` backups.

```{eval-rst}
.. automodule:: pyanimalprocessing.average_over_time
   :members:
   :undoc-members: False
   :show-inheritance:
```

## Average Over Animals

Combine time-averaged backups from a cohort into a weighted mean whose stacks
carry a trailing animal axis (index 0 = mean).

```{eval-rst}
.. automodule:: pyanimalprocessing.average_over_animals
   :members:
   :undoc-members: False
   :show-inheritance:
```
