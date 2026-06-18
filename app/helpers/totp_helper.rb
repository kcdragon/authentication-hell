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

  # In development, the user's current TOTP code (they're enrolled via db/seeds
  # with a known secret) so a code-entry form can prefill it and verifying is one
  # click. Returns nil when prefills are disabled or the user isn't enrolled.
  def dev_totp_prefill(user)
    user.totp&.now if dev_prefills_enabled?
  end
end
