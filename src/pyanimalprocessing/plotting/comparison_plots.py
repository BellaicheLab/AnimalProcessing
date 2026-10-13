"""Statistical comparison plots for two-group tensor aggregates.

The bar + swarm plot used to annotate genotype / condition comparisons in
tissue-mechanics analyses, with a Mann-Whitney U test run inline.
"""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy.stats import mannwhitneyu

_DEFAULT_PALETTE = ["#98C3E4", "#F8AE8B"]  # blue, orange


def compare_genotypes_barplot(
    values_a,
    values_b,
    *,
    label_a=r"V$^{RNAi}$",
    label_b=r"Tollo$^{RNAi}$",
    ylabel="",
    palette=None,
    alternative="two-sided",
):
    """Bar + swarm plot of two samples, annotated ``**`` (p < 0.01), ``*`` (p < 0.05) or ``ns`` by Mann-Whitney U.

    Parameters
    ----------
    values_a, values_b : array-like
        Per-replicate scalar values for the two groups.
    label_a, label_b : str
        X-tick labels for the two groups.
    ylabel : str
        Y-axis label.
    palette : list of str, optional
        Two-colour palette ``[colour_a, colour_b]``.  Default is blue/orange.
    alternative : str
        Passed to ``scipy.stats.mannwhitneyu``.  Default ``"two-sided"``.

    Returns
    -------
    fig : matplotlib.figure.Figure
    p_value : float
        Mann-Whitney two-sample p-value.
    """
    values_a = np.asarray(values_a)
    values_b = np.asarray(values_b)

    _, p_value = mannwhitneyu(values_a, values_b, alternative=alternative)

    group_a = "A"
    group_b = "B"
    df = pd.DataFrame(
        {
            "Value": np.concatenate([values_a, values_b]),
            "Group": [group_a] * len(values_a) + [group_b] * len(values_b),
        }
    )
    mean_positions = df.groupby("Group")["Value"].mean().reindex([group_a, group_b])
    sem_positions = df.groupby("Group")["Value"].sem().reindex([group_a, group_b])

    fig, ax = plt.subplots(figsize=(2.5, 3))

    sns.barplot(
        x="Group",
        y="Value",
        data=df,
        ci=None,
        palette=palette or _DEFAULT_PALETTE,
        edgecolor="black",
        ax=ax,
        alpha=0.8,
        width=0.6,
    )
    sns.swarmplot(
        x="Group",
        y="Value",
        data=df,
        color="black",
        alpha=0.7,
        ax=ax,
        size=2,
        dodge=False,
        edgecolor="gray",
        linewidth=0.5,
    )
    ax.errorbar(
        x=range(len(mean_positions)),
        y=mean_positions.values,
        yerr=sem_positions.values,
        fmt="none",
        ecolor="black",
        capsize=3,
        elinewidth=1,
        capthick=1,
        zorder=10,
    )

    all_vals = np.concatenate([values_a, values_b])
    y_range = np.ptp(all_vals)
    y_min = np.min(all_vals) - 0.1 * y_range
    if np.min(all_vals) >= 0:
        y_min = max(0, y_min)
    y_max = np.max(all_vals) + 0.25 * y_range
    ax.set_ylim(y_min, y_max)

    ax.set_xlabel("Genotype", fontsize=12, labelpad=10)
    ax.set_ylabel(ylabel, fontsize=12, labelpad=10)
    ax.set_xticks([0, 1])
    ax.set_xticklabels([label_a, label_b], fontsize=11)

    bar_height = max(mean_positions.values + sem_positions.values) * 1.1
    ax.hlines(bar_height, 0, 1, color="black", linestyles="solid", lw=1.5, zorder=5)

    if p_value < 0.01:
        sig_text = "**"
    elif p_value < 0.05:
        sig_text = "*"
    else:
        sig_text = "ns"

    ax.text(
        0.5,
        bar_height * 1.02,
        sig_text,
        ha="center",
        va="bottom",
        color="black",
        fontsize=16,
        fontweight="bold",
    )

    ax.grid(axis="y", linestyle="--", alpha=0.3, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout(pad=1.2)

    return fig, p_value