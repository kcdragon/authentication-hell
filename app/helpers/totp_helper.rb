module TotpHelper
  # Renders an otpauth provisioning URI as an inline SVG QR code. The markup is
  # generated entirely by rqrcode from a server-built URI (no user input), so it
  # is safe to mark as HTML.
  def totp_qr_code(provisioning_uri)
    svg = RQRCode::QRCode.new(provisioning_uri).as_svg(
      viewbox: true,
      use_path: true,
      color: "000000",
      shape_rendering: "crispEdges"
    )
    tag.div(svg.html_safe, class: "inline-block w-48 h-48", role: "img", aria: { label: "Two-factor QR code" })
  end
end
