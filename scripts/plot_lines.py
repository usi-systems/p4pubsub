#!/usr/bin/env python
import matplotlib
import os
havedisplay = "DISPLAY" in os.environ
if not havedisplay:
    matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as plticker
import numpy as np
from ConfigParser import ConfigParser
import sys
import argparse
import itertools
import math
import re

matplotlib.rcParams['ps.useafm'] = True
matplotlib.rcParams['pdf.use14corefonts'] = True

def formatLabel(l):
    if matplotlib.rcParams['text.usetex']:
        return l.replace('_', '\\_').replace('%', '\\%')
    return l

#plt.style.use('ggplot')

def _magnitude(x):
    return int(math.floor(math.log10(x)))

def _should_use_log(vals):
    magnitudes = set(map(_magnitude, vals))
    return len(magnitudes) > 1 and len([v for v in vals if v < 1]) > 2

def _tolist(comma_separated_list):
    return map(str.strip, comma_separated_list.split(','))

def load_conf(filename):
    config = ConfigParser()
    config.read(filename)
    return config._sections

def can_cast_to_number(x):
    if type(x) in [int, float]: return True
    if isinstance(x, basestring):
        return x.replace('.','',1).isdigit()
    attrs = ['__add__', '__sub__', '__mul__', '__div__', '__pow__']
    if all(hasattr(x, attr) for attr in attrs): return True
    return False

def int_or_float(x):
    if isinstance(x, basestring):
        try:                return int(x)
        except ValueError:  return float(x)
    else:
        return x

def one_or_more_numbers(x):
    if can_cast_to_number(x):
        return int_or_float(x)
    elif isinstance(x, basestring):
        if ',' not in x: return ValueError("Expects a comma delimited list of numbers")
        return map(int_or_float, x.split(','))
    else:
        raise ValueError("Not a number or list of numbers")

label_style_hist = {} # keep history of styles for labels
label_order_hist = [] # keep history of the order of labels

markers = itertools.cycle(('o', '^', 'D', 's', '+', 'x', '*' ))
linestyles = itertools.cycle(("-","--","-.",":"))
colors = itertools.cycle(('r', 'g', 'b', 'c', 'm', 'y', 'k'))
hatches = itertools.cycle(('x', '/', 'o', '\\', '*', 'o', 'O', '.'))


def plot_bar(data, conf=None, title=None, ylabel=None, label_order=None, show_error=True, show_legend=False):
    field_names = data.dtype.names[1:]
    N = len(field_names)
    ind = np.arange(N)  # the x locations for the groups
    width = 0.2       # the width of the bars

    labels = set([r[0] for r in data])

    local_label_order = []
    if conf and 'linestyle' in conf:
        for lbl, style in conf['linestyle'].items()[1:]:
            if lbl not in labels: continue
            local_label_order.append(lbl)
            label_style_hist[lbl] = dict(zip(['color', 'line', 'marker'], style.split()))
    if conf and 'style' in conf:
        if 'fontsize' in conf['style']: plt.rc('font', size=conf['style']['fontsize'])
        if 'showtitle' in conf['style'] and conf['style']['showtitle'].lower() in ['no', 'false', '0']:
            title = None
        if 'fontweight' in conf['style']:
            plt.rc('font', weight=conf['style']['fontweight'])
            plt.rc('axes', labelweight=conf['style']['fontweight'])
        if 'fontfamily' in conf['style']: plt.rc('font', family=conf['style']['fontfamily'])

    if not local_label_order:
        local_label_order = [l for l in label_order] if label_order else label_order_hist
    unseen_labels = [l for l in labels if not l in local_label_order]
    if all(can_cast_to_number(l) for l in unseen_labels): unseen_labels.sort(key=float)
    local_label_order += unseen_labels

    plot_handles = []
    fig, ax = plt.subplots()
    ax.grid(False)
    ax.set_axisbelow(True)
    ax.yaxis.grid()

    i = 0
    label_names = []
    for lbl in local_label_order:
        vals = [list(r)[1:] for r in data if r[0] == lbl]
        avgs = np.mean(vals, axis=0)
        errs = np.std(vals, axis=0)
        rects = ax.bar(ind + width*i, avgs, width, yerr=errs if show_error else None,
                error_kw=dict(ecolor='black', lw=2, elinewidth=4, capsize=20, capthick=20),
                color='none',
                edgecolor=label_style_hist[lbl]['color'] if lbl in label_style_hist else colors.next(),
                hatch=hatches.next()*2)
        ax.bar(ind + width*i, avgs, width, color='none', edgecolor='k')

        label_name = lbl
        if conf and 'labels' in conf:
            if lbl in conf['labels']: label_name = conf['labels'][lbl]
        label_name = formatLabel(label_name)
        label_names.append(label_name)

        plot_handles.append(rects)
        i += 1

    if ylabel: ax.set_ylabel(formatLabel(ylabel))
    if title: ax.set_title(title)
    ax.set_xticks(ind + width)

    if conf and 'labels' in conf:
        field_titles = [conf['labels'][l] if l in conf['labels'] else l for l in field_names]
    else: field_titles = field_names
    ax.set_xticklabels(field_titles, rotation=30)

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.xaxis.set_ticks_position('bottom')
    ax.yaxis.set_ticks_position('left')

    showlegend = show_legend or conf['showlegend'] if conf and 'showlegend' in conf else True
    if showlegend:
        ax.legend([r[0] for r in plot_handles], label_names,
                loc='upper center',
                bbox_to_anchor=(0.5, 1.12),
                handletextpad=0.2,
                fancybox=True, framealpha=0.0, ncol=3)

    def autolabel(rects):
        # attach some text labels
        for rect in rects:
            height = rect.get_height()
            ax.text(rect.get_x() + rect.get_width()/2., 1.05*height,
                    '%g' % height,
                    ha='center', va='bottom')

    #for r in plot_handles:
    #    autolabel(r)

    fig.tight_layout()
    return fig

def plot_lines(data, xlabel=None, xlim=None, xticks=None, ylabel=None, ylim=None, xscale='linear', yscale='linear',
        title=None, plot_labels=None, label_order=None, show_error=True, show_legend=False, legend_title=None,
        conf=None, linewidth=2, markersize=2, fontsize=None):
    """Plots a 2D array with the format: [[label, x, y, y-dev]]
    """
    if conf and 'units' in conf:
        if ylabel in conf['units']: ylabel = conf['units'][ylabel]
        if xlabel in conf['units']: xlabel = conf['units'][xlabel]

    fig = plt.figure()
    ax = fig.add_subplot(111)

    if conf and 'style' in conf:
        if 'linewidth' in conf['style']: linewidth = int(conf['style']['linewidth'])
        if 'markersize' in conf['style']: markersize = int(conf['style']['markersize'])
        if 'fontsize' in conf['style'] and fontsize is None:
            fontsize = conf['style']['fontsize']
        if fontsize:
            plt.rc('font', size=fontsize)
            ax.xaxis.set_tick_params(labelsize=fontsize)
            ax.yaxis.set_tick_params(labelsize=fontsize)
        if 'showtitle' in conf['style'] and conf['style']['showtitle'].lower() in ['no', 'false', '0']:
            title = None
        if 'fontweight' in conf['style']:
            plt.rc('font', weight=conf['style']['fontweight'])
            plt.rc('axes', labelweight=conf['style']['fontweight'])
        if 'fontfamily' in conf['style']:
            plt.rc('font', family=conf['style']['fontfamily'])

    # Only plot some labels
    if plot_labels:
        data = filter(lambda r: r[0] in plot_labels, data)

    data = sorted(data, key=lambda r: r[1]) # sort data by x values

    local_label_order = []
    if conf and 'linestyle' in conf:
        for lbl, style in conf['linestyle'].items()[1:]:
            local_label_order.append(lbl)
            label_style_hist[lbl] = dict(zip(['color', 'line', 'marker'], style.split()))

    if not local_label_order:
        local_label_order = [l for l in label_order] if label_order else label_order_hist

    if label_order:
        for l in label_order:
            if l not in local_label_order: local_label_order.append(l)
    labels = set([r[0] for r in data])
    unseen_labels = [l for l in labels if not l in local_label_order]
    if all(can_cast_to_number(l) for l in unseen_labels): unseen_labels.sort(key=float)
    local_label_order += unseen_labels

    zoom = False
    if zoom:
        from mpl_toolkits.axes_grid1.inset_locator import zoomed_inset_axes, inset_axes
        axins = inset_axes(ax, 3.2, 3.2, loc=3, bbox_to_anchor=(0.33, 0.2), bbox_transform=ax.figure.transFigure)


    all_x, all_y = [], []
    for label in [l for l in local_label_order if l in labels]:
        if not label in label_style_hist:
            label_style_hist[label] = dict(line=linestyles.next(), marker=markers.next(), color=colors.next())

        points = [tuple(r)[1:4] for r in data if r[0] == label]
        x, y, yerr = zip(*points)
        all_x += x
        all_y += y

        label_name = label
        if conf and 'labels' in conf:
            if label in conf['labels']: label_name = conf['labels'][label]

        label_name = formatLabel(label_name)

        (_, caps, _) = ax.errorbar(x, y, label=label_name, linewidth=linewidth, markersize=markersize,
                elinewidth=1, yerr=yerr if show_error else None,
                color=label_style_hist[label]['color'],
                linestyle=label_style_hist[label]['line'], marker=label_style_hist[label]['marker'])

        if zoom:
            axins.plot(x, y, label=label_name, linewidth=linewidth, markersize=markersize,
                    color=label_style_hist[label]['color'],
                    linestyle=label_style_hist[label]['line'], marker=label_style_hist[label]['marker'])

        for cap in caps:
            cap.set_markeredgewidth(2)

    if zoom:
        axins.set_xlim(10, 1000)
        axins.set_ylim(0, 0.02)
        ticks_x = plticker.FuncFormatter(lambda x, pos: '{0:g}'.format(x).replace('000', 'K') if x in [0, 1000] else '')
        axins.get_xaxis().set_major_formatter(ticks_x)
        axins.get_xaxis().set_ticks(range(0, 1001, 200))
        ticks_y = plticker.FuncFormatter(lambda x, pos: '{0:g}'.format(x) if x in [0, 15, 30] else '')
        axins.get_yaxis().set_major_formatter(ticks_y)
        axins.grid()
        from mpl_toolkits.axes_grid1.inset_locator import mark_inset
        mark_inset(ax, axins, loc1=3, loc2=4, fc="none", ec="0.3")

    if not title is None: ax.set_title(title)
    if not xlabel is None: ax.set_xlabel(formatLabel(xlabel), fontsize=fontsize)
    if not ylabel is None: ax.set_ylabel(formatLabel(ylabel), fontsize=fontsize)

    if not xscale and conf and 'style' in conf and 'xscale' in conf['style']:
        xscale = conf['style']['xscale']
    if xscale: ax.set_xscale(xscale, nonposx='clip')

    if not yscale and conf and 'style' in conf and 'yscale' in conf['style']:
        yscale = conf['style']['yscale']
    if yscale: ax.set_yscale(yscale, nonposx='clip')

    showgrid = True
    if conf and 'style' in conf and 'showgrid' in conf['style']:
        showgrid = conf['style']['showgrid'] == 'True'
    if showgrid:
        # Show a minor grid:
        #ax.set_yticks(ax.get_yticks(), minor=True)
        #ax.set_xticks(range(0, 100000, 20000), minor=True)
        #ax.grid(which='minor') # show only minor grid
        ax.grid(which='both') # show both grids


    y1, y2, x1, x2 = min(all_y), max(all_y), min(all_x), max(all_x)
    if xlim: ax.set_xlim(xlim)
    else: ax.set_xlim([x1, x2])
    if ylim: ax.set_ylim(ylim)
    elif y1 != y2: ax.set_ylim([y1 if y1 < 0 else 0, y2 + (y2-y1)*0.1])
    if xticks:
        if isinstance(xticks, list):
            ax.set_xticks(xticks)
        else:
            loc = plticker.MultipleLocator(base=xticks) # this locator puts ticks at regular intervals
            ax.xaxis.set_major_locator(loc)


    #if _should_use_log(all_x):
    #    ax.set_xscale('symlog', linthreshx=1)

    # Replace thousands with 'K':
    #ticks_x = plticker.FuncFormatter(lambda x, pos: re.sub('000$', 'K', '{0:g}'.format(x)))
    #ax.get_xaxis().set_major_formatter(ticks_x)
    #ticks_y = plticker.FuncFormatter(lambda y, pos: re.sub('000$', 'K', '{0:g}'.format(y)))
    #ax.get_yaxis().set_major_formatter(ticks_y)

    ax.margins(x=0.1)

    showlegend = bool(legend_title)
    if conf and 'style' in conf and 'showlegend' in conf['style']:
        showlegend = conf['style']['showlegend'] == 'True'

    showlegend = show_legend or showlegend

    if showlegend:
        handles, labels = ax.get_legend_handles_labels()
        # remove the errorbars
        handles = [h[0] for h in handles]
        ax.legend(loc='best', fancybox=True, title=legend_title, framealpha=0.5,
                handles=handles, labels=labels, prop={'size': fontsize})

    fig.tight_layout()
    return fig

if __name__ == '__main__':

    get_lim = lambda s: map(float, s.split(','))

    parser = argparse.ArgumentParser(description='')
    parser.add_argument('filename', help='dat filename without extension',
            type=str, action="store")
    parser.add_argument('--format', '-f', help='output format',
            type=str, action="store", choices=['pdf', 'png'], default='png', required=False)
    parser.add_argument('--xlabel', '-x', help='x-axis label',
            type=str, action="store", default=None, required=False)
    parser.add_argument('--xlim', help='x-axis limits',
            type=get_lim, default=None, required=False)
    parser.add_argument('--xticks', help='x-axis tick frequency',
            type=one_or_more_numbers, default=None, required=False)
    parser.add_argument('--ylim', help='y-axis limits',
            type=get_lim, default=None, required=False)
    parser.add_argument('--ylabel', '-y', help='y-axis label',
            type=str, action="store", default=None, required=False)
    parser.add_argument('--xscale', help='x-axis scale',
            type=str, action="store", choices=['linear', 'log', 'symlog'], default=None, required=False)
    parser.add_argument('--yscale', help='y-axis scale',
            type=str, action="store", choices=['linear', 'log', 'symlog'], default=None, required=False)
    parser.add_argument('--title', '-t', help='title',
            type=str, action="store", default=None, required=False)
    parser.add_argument('--linewidth', '-w', help='line width',
            type=int, action="store", default=2, required=False)
    parser.add_argument('--markersize', '-m', help='marker size',
            type=int, action="store", default=4, required=False)
    parser.add_argument('--conf', '-c', help='A python config file with [style] and [labels] sections',
            type=str, required=False, default=None)
    parser.add_argument('--font-size', help='Font size',
            type=str, required=False, default=None)
    parser.add_argument('--label-order', '-L', help='Comma-separated list of the ordering of labels in the plot',
            type=str, default=None, required=False)
    parser.add_argument('--labels', help='Comma-separated list of labels to plot',
            type=_tolist, default=None, required=False)
    parser.add_argument('--no-error', help='Do not display error bars on the plot',
            action='store_true', default=False)
    parser.add_argument('--show', help='Open the plot in a new window',
            action='store_true', default=False)
    parser.add_argument('--legend', help='Add a legend to the plot',
            action='store', default=False, const=None, nargs='?')
    parser.add_argument('--bar', help='Plot a bar chart',
            action='store_true', default=False)
    args = parser.parse_args()

    if args.filename == '-':
        title = '-'
        file_in = sys.stdin
        file_out = 'out.' + args.format
    else:
        file_in = args.filename
        title = os.path.splitext(args.filename)[0]
        file_out = os.path.splitext(args.filename)[0] + '.' + args.format

    data = np.genfromtxt(file_in, delimiter='\t', names=True, dtype=None, encoding=None)

    if args.title is not None: title = args.title if args.title else None

    conf = load_conf(args.conf) if args.conf else {}

    if args.format == 'pdf':
        matplotlib.rcParams['text.usetex'] = True

    if 'style' in conf and 'usetex' in conf['style']:
        matplotlib.rcParams['text.usetex'] = conf['style']['usetex']

    if args.bar:
        fig = plot_bar(data, title=title,
            conf=conf,
            show_error=not args.no_error,
            show_legend=args.legend,
            ylabel=args.ylabel)
    else:
        fig = plot_lines(data, title=title,
            conf=conf,
            linewidth=args.linewidth,
            show_error=not args.no_error,
            show_legend=args.legend is not False,
            legend_title=args.legend,
            xlim=args.xlim, ylim=args.ylim, xticks=args.xticks,
            xlabel=args.xlabel or data.dtype.names[1],
            ylabel=args.ylabel or data.dtype.names[2],
            xscale=args.xscale,
            yscale=args.yscale,
            fontsize=args.font_size,
            markersize=args.markersize,
            plot_labels=args.labels,
            label_order=_tolist(args.label_order) if args.label_order else None)

    fig.savefig(file_out)
    if args.show: plt.show()
