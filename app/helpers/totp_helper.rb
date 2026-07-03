module TotpHelper
  # html_safe is safe here: the SVG comes entirely from rqrcode rendering a server-built URI.
  def totp_qr_code(provisioning_uri)
    svg = RQRCode::QRCode.new(provisioning_uri).as_svg(
      viewbox: true,
      use_path: true,
      color: "000000",
      shape_rendering: "crispEdges"
    )
    tag.div(svg.html_safe, class: "inline-block w-48 h-48", role: "img", aria: { label: "Two-factor QR code" })
  end

  def dev_totp_prefill(user)
    user.totp&.now if dev_prefills_enabled?
  end
end
