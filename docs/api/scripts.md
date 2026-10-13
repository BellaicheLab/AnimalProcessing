# Scripts

## Zarr Conversion CLI

`zarrify_SAP` and `zarrify_MAP` are the console scripts installed with the
package:

- `zarrify_SAP <animal_path> [...] [--SAP_info_path ...] [--output_path ...] [--gridsize LGrid]` — convert one or more single-animal SAP folders to zarr.
- `zarrify_MAP <average_path> [...] [--output_path ...]` — convert AOA/DBA average folders to zarr.

```{eval-rst}
.. automodule:: pyanimalprocessing.scripts.zarrify
   :members:
   :undoc-members: False
   :show-inheritance:
```
