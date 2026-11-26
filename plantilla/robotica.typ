// ============================================================
//  Plantilla de guías — Robótica
//  Uso:  #import "../plantilla/robotica.typ": *
//        #show: guia.with(numero: "04", titulo: [...], ...)
// ============================================================

#let tinta = rgb("#1d2433")
#let gris = rgb("#6b7280")
#let gris-claro = rgb("#eef0f4")
#let fondo-codigo = rgb("#f6f7f9")
#let terminal = rgb("#1e2230")

// Color de acento de la guía (se fija con #show: guia.with(color: ...))
#let acento = state("acento", rgb("#2563eb"))

// ------------------------------------------------------------
//  Utilidades de dibujo
// ------------------------------------------------------------

/// Flecha de a → b (coordenadas absolutas dentro de un box).
#let flecha(a, b, color: tinta, grosor: 1.1pt, punta: 6pt) = {
  let (x1, y1) = a
  let (x2, y2) = b
  let ang = calc.atan2((x2 - x1) / 1pt, (y2 - y1) / 1pt)
  let p1 = (x2 - punta * calc.cos(ang - 24deg), y2 - punta * calc.sin(ang - 24deg))
  let p2 = (x2 - punta * calc.cos(ang + 24deg), y2 - punta * calc.sin(ang + 24deg))
  place(line(start: a, end: b, stroke: grosor + color))
  place(polygon(fill: color, stroke: none, b, p1, p2))
}

/// Etiqueta de texto centrada en un punto.
#let etiqueta(p, cuerpo, tam: 9pt, color: tinta) = {
  let (x, y) = p
  place(dx: x, dy: y, place(center + horizon, text(size: tam, fill: color, cuerpo)))
}

/// Gráfica de funciones y = f(x) dibujada con primitivas de Typst.
#let grafica(
  series,
  ancho: 7cm,
  alto: 4.2cm,
  xmin: 0.0,
  xmax: 1.0,
  ymin: 0.0,
  ymax: 1.0,
  n: 80,
  xlabel: none,
  ylabel: none,
  leyenda: true,
  leyenda-pos: top + right,
) = {
  let px(x) = (x - xmin) / (xmax - xmin) * ancho
  let py(y) = alto - (y - ymin) / (ymax - ymin) * alto
  box(width: ancho, height: alto + 14pt, {
    // rejilla
    for i in range(5) {
      let y = i / 4 * alto
      place(line(start: (0pt, y), end: (ancho, y), stroke: 0.4pt + gris-claro.darken(8%)))
    }
    // ejes (y = 0 si está en el rango)
    if ymin < 0 and ymax > 0 {
      place(line(start: (0pt, py(0)), end: (ancho, py(0)), stroke: 0.6pt + gris))
    }
    place(line(start: (0pt, alto), end: (ancho, alto), stroke: 0.8pt + tinta))
    place(line(start: (0pt, 0pt), end: (0pt, alto), stroke: 0.8pt + tinta))
    for s in series {
      let (f, col) = (s.at(0), s.at(1))
      let pts = range(n + 1).map(i => {
        let x = xmin + i / n * (xmax - xmin)
        (px(x), py(f(x)))
      })
      place(curve(
        stroke: 1.6pt + col,
        curve.move(pts.at(0)),
        ..pts.slice(1).map(p => curve.line(p)),
      ))
    }
    if xlabel != none { place(dx: ancho - 2cm, dy: alto + 4pt, box(width: 2cm, align(right, text(8pt, fill: gris, xlabel)))) }
    if ylabel != none { place(dx: 4pt, dy: -2pt, text(8pt, fill: gris, ylabel)) }
    if leyenda {
      let items = series.filter(s => s.len() > 2)
      place(leyenda-pos, dx: if leyenda-pos.x == right { -4pt } else { 0pt }, dy: 4pt, box(fill: white.transparentize(10%), inset: 4pt, radius: 3pt,
        stack(spacing: 3pt, ..items.map(s => stack(dir: ltr, spacing: 4pt,
          box(width: 12pt, height: 2pt, fill: s.at(1), baseline: -2pt), text(7.5pt, s.at(2)))))))
    }
  })
}

/// Cadena de bloques A → B → C (para flujos de datos entre nodos/tópicos).
#let flujo(..pasos, color: auto) = context {
  let c = if color == auto { acento.get() } else { color }
  let items = pasos.pos()
  let celdas = ()
  for (i, p) in items.enumerate() {
    let es-topico = type(p) == str and p.starts-with("/")
    celdas.push(box(
      inset: (x: 8pt, y: 6pt),
      radius: if es-topico { 12pt } else { 4pt },
      fill: if es-topico { c.lighten(88%) } else { white },
      stroke: if es-topico { 0.8pt + c } else { 1pt + tinta },
      text(size: 8.5pt, font: if es-topico { "DejaVu Sans Mono" } else { "Lato" }, weight: if es-topico { "regular" } else { "bold" }, p),
    ))
    if i < items.len() - 1 { celdas.push(text(fill: c, size: 13pt, sym.arrow.r)) }
  }
  align(center, block(above: 1em, below: 1em, stack(dir: ltr, spacing: 6pt, ..celdas.map(x => box(baseline: 30%, x)))))
}

// ------------------------------------------------------------
//  Componentes de contenido
// ------------------------------------------------------------

#let _caja(etq, icono, col, cuerpo) = block(
  width: 100%,
  fill: col.lighten(92%),
  stroke: (left: 3pt + col),
  inset: (left: 12pt, right: 12pt, y: 10pt),
  radius: (right: 4pt),
  above: 1.1em,
  below: 1.1em,
  breakable: false,
)[
  #text(size: 8.5pt, weight: "bold", fill: col.darken(15%), tracking: 0.6pt, upper(icono + h(5pt) + etq))
  #v(-2pt)
  #cuerpo
]

#let idea(cuerpo) = _caja("Idea clave", "◆", rgb("#2563eb"), cuerpo)
#let cuidado(cuerpo) = _caja("Cuidado", "▲", rgb("#d97706"), cuerpo)
#let tip(cuerpo) = _caja("Sugerencia", "✦", rgb("#059669"), cuerpo)
#let reto(cuerpo) = _caja("Reto", "★", rgb("#7c3aed"), cuerpo)

/// Bloque de actividad numerada.
#let actividad(num, titulo, cuerpo) = context {
  let c = acento.get()
  layout(tam => {
  // las actividades que caben en ~media página no se parten
  let alto = measure(block(width: tam.width - 24pt, cuerpo)).height
  block(width: 100%, above: 1.4em, below: 1.2em, breakable: alto > 15cm, stroke: 0.8pt + c.lighten(55%), radius: 5pt, clip: true)[
    #block(width: 100%, fill: c.lighten(85%), inset: (x: 12pt, y: 7pt), below: 0pt, sticky: true)[
      #text(weight: "bold", fill: c.darken(25%), size: 9.5pt)[ACTIVIDAD #num] #h(6pt) #text(weight: "bold", size: 10.5pt, titulo)
    ]
    #block(inset: (x: 12pt, top: 10pt, bottom: 12pt), width: 100%, cuerpo)
  ]
  })
}

/// Lista de preguntas para el informe.
#let preguntas(cuerpo) = context {
  let c = acento.get()
  block(width: 100%, fill: gris-claro.lighten(30%), inset: 12pt, radius: 5pt, above: 1.2em, below: 1.2em, breakable: false)[
    #text(size: 8.5pt, weight: "bold", fill: c.darken(20%), tracking: 0.6pt)[? #h(3pt) PREGUNTAS PARA EL INFORME]
    #v(-2pt)
    #set enum(numbering: n => text(fill: c, weight: "bold", str(n) + "."))
    #cuerpo
  ]
}

/// Encabezado de archivo para un bloque de código.
#let archivo(nombre, codigo) = context {
  let c = acento.get()
  let n = if codigo.has("text") { codigo.text.split("\n").len() } else { 0 }
  block(above: 1em, below: 1em, breakable: n > 38)[
    #block(below: 0pt, sticky: true, fill: c.darken(10%), inset: (x: 10pt, y: 4pt), radius: (top: 4pt))[
      #text(fill: white, size: 8pt, font: "DejaVu Sans Mono", nombre)
    ]
    #codigo
  ]
}

/// Tabla con estilo de la guía.
#let tabla(columnas: auto, alinear: left, ..celdas) = context {
  let c = acento.get()
  block(above: 1em, below: 1em, table(
    columns: columnas,
    align: alinear,
    stroke: (x, y) => (bottom: if y == 0 { 1pt + c } else { 0.5pt + gris-claro.darken(10%) }),
    fill: (x, y) => if y == 0 { c.lighten(88%) },
    inset: (x: 8pt, y: 6pt),
    ..celdas,
  ))
}

/// Lista de verificación de entregables.
#let entregables(..items) = context {
  let c = acento.get()
  block(width: 100%, stroke: 1pt + c, radius: 5pt, inset: 12pt, above: 1.2em, breakable: false)[
    #text(size: 8.5pt, weight: "bold", fill: c.darken(20%), tracking: 0.6pt)[✓ #h(3pt) QUÉ ENTREGAR]
    #v(2pt)
    #for it in items.pos() [
      #box(width: 9pt, height: 9pt, stroke: 1pt + c, radius: 2pt, baseline: 1pt) #h(5pt) #it \
    ]
  ]
}

// ------------------------------------------------------------
//  Documento
// ------------------------------------------------------------

#let guia(
  numero: "00",
  titulo: [Título],
  subtitulo: none,
  capitulo: none,
  herramientas: (),
  duracion: none,
  objetivos: (),
  color: rgb("#2563eb"),
  cuerpo,
) = {
  set document(title: "Robótica — Guía " + numero, author: "Laboratorios de Robótica")
  set text(font: ("Lato", "Libertinus Serif"), size: 10.5pt, lang: "es", fill: tinta)
  set par(justify: true, leading: 0.7em, spacing: 1.15em)
  show math.equation: set text(font: "New Computer Modern Math")

  set page(
    paper: "us-letter",
    margin: (x: 2.2cm, top: 2.5cm, bottom: 2.3cm),
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8.5pt, fill: gris)
        grid(columns: (1fr, auto), align: (left, right),
          [*Robótica* · Guía #numero], titulo)
        v(-4pt)
        line(length: 100%, stroke: 0.5pt + gris-claro.darken(10%))
      }
    },
    footer: context {
      set text(size: 8pt, fill: gris)
      grid(columns: (1fr, auto), align: (left, right),
        [Universidad Nacional de Colombia · Sede Manizales],
        box(fill: color.lighten(85%), inset: (x: 7pt, y: 3pt), radius: 8pt,
          text(fill: color.darken(25%), weight: "bold", counter(page).display("1 / 1", both: true))))
    },
  )

  acento.update(color)

  // Encabezados
  set heading(numbering: "1.1")
  show heading.where(level: 1): it => {
    v(1.2em, weak: true)
    block(below: 0.9em, sticky: true, grid(columns: (auto, 1fr), column-gutter: 10pt, align: horizon,
      box(fill: color, radius: 4pt, inset: (x: 7pt, y: 5pt),
        text(fill: white, weight: "bold", size: 11pt, counter(heading).display("1"))),
      text(size: 15pt, weight: "bold", it.body)))
  }
  show heading.where(level: 2): it => {
    v(0.6em, weak: true)
    block(below: 0.7em, sticky: true, text(size: 11.5pt, weight: "bold", fill: color.darken(20%),
      counter(heading).display() + h(8pt) + it.body))
  }
  show heading.where(level: 3): it => block(below: 0.6em, sticky: true, text(size: 10.5pt, weight: "bold", it.body))

  // Listas
  set list(marker: (text(fill: color, "•"), text(fill: color, "–")), indent: 4pt)
  set enum(indent: 4pt)

  // Código
  show raw: set text(font: "DejaVu Sans Mono", size: 8.3pt)
  show raw.where(block: false): it => box(fill: gris-claro, inset: (x: 3pt), outset: (y: 2.5pt), radius: 2pt, it)
  show raw.where(block: true): it => {
    let es-terminal = it.lang in ("bash", "sh", "console")
    if es-terminal {
      set text(fill: rgb("#e6e9ef"))
      block(width: 100%, fill: terminal, inset: (x: 12pt, y: 10pt), radius: 4pt, above: 0.9em, below: 0.9em,
        grid(columns: (auto, 1fr), column-gutter: 6pt, row-gutter: 0.6em,
          ..it.lines.map(l => {
            let t = l.text
            if t.trim().starts-with("#") { (text(fill: rgb("#8b93a7"), "#"), text(fill: rgb("#8b93a7"), t.trim().slice(1).trim())) }
            else if t.trim() == "" { ([], []) }
            else if t.starts-with(" ") { ([], text(fill: rgb("#e6e9ef"), t.trim())) }
            else { (text(fill: rgb("#7ee0a8"), "$"), text(fill: rgb("#e6e9ef"), t)) }
          }).flatten()))
    } else {
      block(width: 100%, fill: fondo-codigo, stroke: 0.5pt + gris-claro.darken(8%), inset: (x: 10pt, y: 9pt), radius: (bottom: 4pt, top: 4pt), above: 0.9em, below: 0.9em, breakable: it.lines.len() > 38,
        grid(columns: (auto, 1fr), column-gutter: 10pt, row-gutter: 0.55em,
          ..it.lines.map(l => (text(fill: gris.lighten(20%), size: 7pt, str(l.number)), l)).flatten()))
    }
  }

  // Figuras
  show figure.caption: set text(size: 8.8pt, fill: gris)
  set figure(gap: 0.8em)

  // ---------------- Portada ----------------
  block(width: 100%, radius: 10pt, clip: true, fill: gradient.linear(color.darken(35%), color, angle: 20deg), inset: 0pt)[
    #block(inset: (x: 24pt, top: 20pt, bottom: 22pt), width: 100%)[
      #grid(columns: (1fr, auto), align: (left + top, right + top),
        text(fill: white.transparentize(25%), size: 8.5pt, weight: "bold", tracking: 1.5pt)[ROBÓTICA · GUÍA DE LABORATORIO],
        text(fill: white.transparentize(20%), size: 8.5pt, weight: "bold", tracking: 1pt, if capitulo != none [CORKE · CAP. #capitulo]),
      )
      #v(10pt)
      #grid(columns: (auto, 1fr), column-gutter: 16pt, align: (left + bottom, left + bottom),
        text(fill: white.transparentize(55%), size: 54pt, weight: "black", numero),
        [
          #text(fill: white, size: 22pt, weight: "bold", titulo)
          #if subtitulo != none { v(-6pt); text(fill: white.transparentize(15%), size: 11.5pt, subtitulo) }
        ],
      )
    ]
  ]

  // Ficha técnica
  v(6pt)
  {
    let ficha(etq, val) = block(width: 100%, fill: gris-claro.lighten(40%), radius: 5pt, inset: (x: 10pt, y: 8pt))[
      #set par(justify: false)
      #text(size: 7.5pt, fill: gris, weight: "bold", tracking: 0.5pt, upper(etq)) \
      #text(size: 9pt, val)
    ]
    let celdas = ()
    if herramientas.len() > 0 { celdas.push(ficha("Herramientas", herramientas.join(" · "))) }
    if duracion != none { celdas.push(ficha("Duración estimada", duracion)) }
    if capitulo != none { celdas.push(ficha("Referencia", [P. Corke, _Robotics, Vision and Control_ (Python), cap. #capitulo])) }
    let cols = if celdas.len() == 3 { (1.4fr, 0.9fr, 1.3fr) } else if celdas.len() == 2 { (2fr, 1fr) } else { (1fr,) }
    grid(columns: cols, column-gutter: 8pt, ..celdas)
  }

  if objetivos.len() > 0 {
    block(width: 100%, above: 12pt, below: 16pt, stroke: (left: 3pt + color), inset: (left: 14pt, y: 4pt))[
      #text(size: 8.5pt, weight: "bold", fill: color.darken(20%), tracking: 0.8pt)[AL TERMINAR ESTA PRÁCTICA PODRÁS]
      #v(-3pt)
      #set list(marker: text(fill: color, sym.arrow.r))
      #for o in objetivos [- #o]
    ]
  }

  cuerpo
}
