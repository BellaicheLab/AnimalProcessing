"""Stages the bundled atlas samples into the layout used by 02_build_an_expression_atlas."""

import glob
import shutil
from pathlib import Path

import numpy as np
import pandas as pd
import zarr


def stage_atlas_samples(atlas_stores, work, atlas_table, n_genes, samples_per_gene):
    """Pick the ``n_genes`` best-covered genes of the atlas (most well-registered
    samples, restricted to genes present in the published table), lay out the
    tutorial's ``microscopy/<gene>/<sample>/{raw,mask}`` folders (placeholders — the
    raw TIFs are not distributed), and put each assembled store at the path the
    notebook's assembly loop writes to, keeping any store already there. Returns
    ``(microscopy, genes)``."""
    table_genes = set(pd.read_csv(atlas_table, nrows=1).columns)
    candidates = {}
    for path in sorted(glob.glob(str(atlas_stores / "*/*.zarr"))):
        probe = zarr.open(path, mode="r")
        gene = probe.attrs.get("gene")
        if gene not in table_genes:
            continue
        landmarks = probe["SPACE_REGISTRATION/atlas_sr/landmarks"][:]
        if (~np.isnan(landmarks).any(axis=1)).sum() < 4:
            continue
        candidates.setdefault(gene, []).append(path)

    genes = sorted(candidates, key=lambda g: (-len(candidates[g]), g.lower()))[:n_genes]

    microscopy = work / "microscopy"
    for gene in genes:
        for path in candidates[gene][:samples_per_gene]:
            name = Path(path).stem
            (microscopy / gene / name / "raw").mkdir(parents=True, exist_ok=True)
            (microscopy / gene / name / "mask").mkdir(exist_ok=True)
            store = work / "stores" / f"{name}.zarr"
            if not store.exists():
                shutil.copytree(path, store)
    return microscopy, genes
