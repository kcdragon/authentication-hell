module AttractHelper
  def play_qr_code(url)
    svg = RQRCode::QRCode.new(url).as_svg(
      viewbox: true,
      use_path: true,
      color: "111111",
      shape_rendering: "crispEdges"
    )
    # html_safe is safe here: the SVG comes entirely from rqrcode rendering a server-built URL.
    tag.div(svg.html_safe, class: "w-full h-full [&>svg]:w-full [&>svg]:h-full", role: "img",
      aria: { label: "Scan to play Authentication Hell" })
  end
end
