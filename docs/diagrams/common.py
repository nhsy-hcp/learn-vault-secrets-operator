"""Shared style for the lab diagrams (rendered with mingrammer/diagrams + Graphviz).

Style follows the learn-vault-proxy overview: rounded, colour-coded groups, bold titles with a
muted detail line, numbered step badges, green delivery hops and dashed grey reference links.
Icons are the official ones bundled with the diagrams library.
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge, Node, getdiagram

OUT_DIR = Path(__file__).resolve().parent.parent / "images"
FONT = "Helvetica"

# palette (Tailwind-ish, matches the reference image)
BLUE, BLUE_FILL = "#2563eb", "#eff6ff"
ORANGE, ORANGE_FILL = "#ea580c", "#fff7ed"
GREY, GREY_FILL = "#374151", "#f3f4f6"
GREEN, GREEN_FILL = "#15803d", "#ecfdf5"
YELLOW, YELLOW_FILL = "#d97706", "#fffbeb"
MUTED, REF = "#4b5563", "#9ca3af"


def label(title: str, detail: str = "") -> str:
    """Bold title with an optional muted detail line (Graphviz HTML label)."""
    lines = "".join(
        f'<br/><font point-size="11" color="{MUTED}">{line}</font>' for line in detail.split("\n") if line
    )
    return f"<<b>{title}</b>{lines}>"


def icon(cls, title: str, detail: str = "", **attrs) -> Node:
    """Official icon node; pads the height for each label line so text never overlaps the icon."""
    lines = 1 + len([line for line in detail.split("\n") if line])
    return cls(label=label(title, detail), height=str(1.9 + 0.32 * lines), **attrs)


def diagram(name: str, direction: str = "LR", **graph) -> Diagram:
    """graph: per-diagram Graphviz overrides, e.g. nodesep="1.8"."""
    return Diagram(
        "",
        filename=str(OUT_DIR / name),
        outformat="png",
        show=False,
        direction=direction,
        graph_attr={
            "fontname": FONT,
            "bgcolor": "white",
            "pad": "0.4",
            "nodesep": "1.2",
            "ranksep": "1.3",
            "splines": "spline",
            "dpi": "160",
            "compound": "true",
            "newrank": "true",  # lets same_rank() align nodes across clusters
            **graph,
        },
        node_attr={"fontname": FONT, "fontsize": "13"},
        edge_attr={"fontname": FONT, "fontsize": "12", "penwidth": "1.8", "color": GREY, "arrowsize": "0.8"},
    )


def group(title: str, colour: str = ORANGE, fill: str = ORANGE_FILL) -> Cluster:
    return Cluster(
        title,
        graph_attr={
            "style": "rounded,filled",
            "pencolor": colour,
            "fillcolor": fill,
            "penwidth": "2",
            "fontname": f"{FONT} Bold",
            "fontcolor": colour,
            "fontsize": "15",
            "labeljust": "c",
            "margin": "18",
        },
    )


def app_ns(title: str) -> Cluster:
    return group(title, ORANGE, ORANGE_FILL)


def vso_ns(title: str = "vault-secrets-operator") -> Cluster:
    return group(title, BLUE, BLUE_FILL)


def vault_ns(title: str = "Vault Enterprise · namespace tn001") -> Cluster:
    return group(title, GREY, GREY_FILL)


def same_rank(*nodes: Node) -> None:
    """Pin nodes to one rank: a column in LR diagrams, a row in TB diagrams (works across clusters)."""
    with getdiagram().dot.subgraph() as sub:
        sub.attr(rank="same")
        for node in nodes:
            sub.node(node._id)


def hidden(a: Node, b: Node) -> None:
    """Invisible edge, used only to order nodes."""
    a >> Edge(style="invis") >> b


def box(title: str, detail: str = "", colour: str = GREY, fill: str = "white", **attrs) -> Node:
    """Icon-less rounded box, used for Vault paths, policies and files."""
    return Node(
        label=label(title, detail),
        shape="box",
        style="rounded,filled",
        color=colour,
        fillcolor=fill,
        penwidth="2",
        margin="0.25,0.12",
        fixedsize="false",
        width="0",
        height="0",
        labelloc="c",
        imagescale="false",
        **attrs,
    )


def note(text: str, **attrs) -> Node:
    """Yellow call-out box for the key takeaway of a diagram."""
    return Node(
        label=f'<<font point-size="12">{text}</font>>',
        shape="box",
        style="rounded,filled",
        color=YELLOW,
        fillcolor=YELLOW_FILL,
        penwidth="1.5",
        margin="0.3,0.15",
        fixedsize="false",
        width="0",
        height="0",
        labelloc="c",
        **attrs,
    )


def _badge(n: int, text: str, colour: str) -> str:
    cell = (
        f'<td><table border="0" style="rounded" bgcolor="{colour}" cellpadding="3"><tr><td>'
        f'<font color="white" point-size="12"><b> {n} </b></font></td></tr></table></td>'
    )
    txt = f'<td align="left"> {text}</td>' if text else ""
    return f'<<table border="0" cellspacing="0" cellpadding="1"><tr>{cell}{txt}</tr></table>>'


def step(n: int, text: str = "", external: bool = False, **attrs) -> Edge:
    """Numbered step of the main flow (blue badge).

    external=True places the badge beside the edge (Graphviz xlabel) instead of on it, for short edges
    whose midpoint would land on a group border.
    """
    key = "xlabel" if external else "label"
    return Edge(**{key: _badge(n, text, BLUE)}, **attrs)


def deliver(n: int | None = None, text: str = "", **attrs) -> Edge:
    """Delivery of the secret to the workload (green)."""
    lbl = _badge(n, text, GREEN) if n else (f'<<font color="{GREEN}"><b>{text}</b></font>>' if text else "")
    return Edge(label=lbl, color=GREEN, penwidth="2.2", **attrs)


def ref(text: str = "", n: int | None = None, **attrs) -> Edge:
    """Reference / configuration link (dashed grey)."""
    lbl = _badge(n, text, REF) if n else (f'<<font color="{MUTED}">{text}</font>>' if text else "")
    return Edge(label=lbl, style="dashed", color=REF, **attrs)
