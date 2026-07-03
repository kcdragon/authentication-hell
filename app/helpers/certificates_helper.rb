module CertificatesHelper
  def certificate_qr_code(url)
    svg = RQRCode::QRCode.new(url).as_svg(
      viewbox: true,
      use_path: true,
      color: "111111",
      shape_rendering: "crispEdges"
    )
    tag.div(svg.html_safe, class: "w-20 h-20", role: "img", aria: { label: "Verification QR code" })
  end
end
