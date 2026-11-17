"""Render the recorded PasTiny comparisons: python3 BENCH/PLOT.PY.

Requires matplotlib. FPU-on and FPU-off use different workloads and are
intentionally plotted separately. No new benchmark runs are performed.
"""
from pathlib import Path
import csv
import os
import tempfile

# Use a private writable cache when the caller has not configured one.
_cache = tempfile.TemporaryDirectory(prefix='pastiny-plots-')
os.environ.setdefault('MPLCONFIGDIR', _cache.name)
os.environ.setdefault('XDG_CACHE_HOME', _cache.name)
import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator

ROOT = Path(__file__).resolve().parent
COLORS = {
    'FPC integer': '#0072B2',
    'TP7 integer ASM': '#009E73',
    'FPC float': '#56B4E9',
    'Original C': '#87919F',
    'TP7 integer Pascal': '#E69F00',
    'TP7 float': '#CC79A7',
}
LABELS = {'TP7 integer Pascal': 'TP7 integer (pure Pascal)'}
plt.rcParams.update({
    'font.family': 'DejaVu Sans',
    'font.size': 11,
    'axes.labelcolor': '#334155',
    'text.color': '#172033',
    'xtick.color': '#64748B',
    'ytick.color': '#172033',
    'svg.hashsalt': 'pastiny-benchmark-2026-11-17',
    'svg.fonttype': 'none',
})
with (ROOT / 'BENCH.CSV').open(newline='') as stream:
    records = list(csv.DictReader(stream))

for mode, name in [('on', 'FPUON'), ('off', 'FPUOFF')]:
    rows = sorted((r for r in records if r['fpu'] == mode),
                  key=lambda r: float(r['seconds_per_answer']))
    if mode == 'on':
        assert len(rows) == 6
        assert all((r['runs'], r['questions'], r['tokens']) == ('3', '5', '189') for r in rows)
        title = 'FPU enabled'
        subtitle = 'Five questions | median of three runs | 189 character tokens per run'
        xlabel = 'Average seconds per answer (lower is faster)'
        footer = 'Median whole-program time divided by five answers. Startup, model load and output included.'
        max_x, interval = 12.4, 2
    else:
        assert len(rows) == 4
        assert all((r['runs'], r['questions'], r['tokens']) == ('1', '1', '34') for r in rows)
        title = 'FPU disabled'
        subtitle = 'One question: "what is 7 times 8" | one run per build | 34 character tokens'
        xlabel = 'Seconds for the test question (lower is faster)'
        footer = 'Whole-program time includes startup, model load and output. FPC no-FPU runs are not validated.'
        max_x, interval = 320, 50
    values = [float(r['seconds_per_answer']) for r in rows]
    fig, ax = plt.subplots(figsize=(11.8, 5.7), facecolor='white')
    fig.subplots_adjust(left=0.27, right=0.965, top=0.76, bottom=0.27)
    ax.set_facecolor('white')
    bars = ax.barh(range(len(rows)), values, height=0.61,
                   color=[COLORS[r['version']] for r in rows], zorder=3)
    ax.invert_yaxis()
    ax.set_yticks(range(len(rows)), [LABELS.get(r['version'], r['version']) for r in rows])
    ax.tick_params(axis='y', length=0, pad=12)
    ax.tick_params(axis='x', length=0, pad=8)
    ax.set_xlim(0, max_x)
    ax.xaxis.set_major_locator(MultipleLocator(interval))
    ax.grid(axis='x', color='#E2E8F0', linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.axvline(0, color='#CBD5E1', linewidth=1, zorder=2)
    for bar, value in zip(bars, values):
        ax.text(value + max_x * 0.015, bar.get_y() + bar.get_height() / 2,
                f'{value:.2f} s', va='center', fontsize=11, fontweight='bold')
    ax.set_xlabel(xlabel, labelpad=14)
    fig.text(0.045, 0.925, title, fontsize=23, fontweight='bold')
    fig.text(0.045, 0.865, subtitle, fontsize=11, color='#475569')
    fig.text(0.045, 0.125, 'DOSBox-X 2025.02.01 | normal core | emulated 386 | 50,000 fixed cycles | 16 MB',
             fontsize=9, color='#475569')
    fig.text(0.045, 0.080, footer, fontsize=9, color='#475569')
    fig.text(0.045, 0.035, 'Emulator comparison, not a physical Pocket386 timing prediction. All timed answers matched.',
             fontsize=9, color='#475569')
    fig.savefig(ROOT / f'{name}.SVG', format='svg', metadata={'Date': None, 'Creator': 'PasTiny benchmark plotter'})
    fig.savefig(ROOT / f'{name}.PNG', format='png', dpi=180, metadata={'Software': 'PasTiny benchmark plotter'})
    plt.close(fig)
    svg_path = ROOT / f'{name}.SVG'
    svg_path.write_text('\n'.join(line.rstrip() for line in svg_path.read_text().splitlines()) + '\n')
    print(f'{name}: {len(rows)} verified data rows plotted')
