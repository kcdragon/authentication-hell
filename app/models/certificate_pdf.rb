class CertificatePdf
  INK      = "111111"
  PAPER    = "F5F2E9"
  GOLD     = "F5A623"
  BLUE     = "2F6BFF"
  MUTED    = "5B5750"

  FONTS = Rails.root.join("game/mygame/fonts")
  DISPLAY = FONTS.join("archivo-black-400.ttf").to_s
  MONO    = FONTS.join("space-mono-400.ttf").to_s
  MONO_B  = FONTS.join("space-mono-700.ttf").to_s

  def self.call(user, verify_url:)
    new(user, verify_url).call
  end

  def initialize(user, verify_url)
    @user = user
    @verify_url = verify_url
  end

  def call
    doc = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: 0)
    register_fonts(doc)
    background(doc)
    frame(doc)
    body(doc)
    verification(doc)
    doc.render
  end

  private

  def register_fonts(doc)
    doc.font_families.update(
      "Display" => { normal: DISPLAY },
      "Mono"    => { normal: MONO, bold: MONO_B }
    )
  end

  def background(doc)
    doc.canvas do
      doc.fill_color PAPER
      doc.fill_rectangle [ 0, doc.bounds.top ], doc.bounds.width, doc.bounds.height
    end
  end

  def frame(doc)
    doc.canvas do
      doc.stroke_color INK
      doc.line_width 6
      doc.stroke_rectangle [ 28, doc.bounds.top - 28 ], doc.bounds.width - 56, doc.bounds.height - 56
      doc.stroke_color GOLD
      doc.line_width 2
      doc.stroke_rectangle [ 42, doc.bounds.top - 42 ], doc.bounds.width - 84, doc.bounds.height - 84
    end
    doc.stroke_color INK
    doc.fill_color INK
  end

  def body(doc)
    centered(doc, 470, "AUTHENTICATION HELL", font: "Mono", style: :bold, size: 15, spacing: 4, color: MUTED)
    centered(doc, 430, "CERTIFICATE OF COMPLETION", font: "Display", size: 34)

    doc.fill_color GOLD
    doc.fill_rectangle [ doc.bounds.width / 2 - 60, 388 ], 120, 5
    doc.fill_color INK

    centered(doc, 360, "THIS CERTIFIES THAT", font: "Mono", size: 13, spacing: 2, color: MUTED)
    centered(doc, 330, @user.username, font: "Display", size: 46)

    centered(doc, 250, completion_line, font: "Mono", size: 13, color: INK, width: 560, leading: 6)
    centered(doc, 150, "Awarded #{@user.certificate_awarded_at.to_date.to_fs(:long)}",
      font: "Mono", style: :bold, size: 13, spacing: 1, color: MUTED)
  end

  def completion_line
    "has descended through every circle of Authentication Hell — passwords, " \
    "time-based one-time passwords, and passkeys — and lived to tell of it."
  end

  def verification(doc)
    modules = RQRCode::QRCode.new(@verify_url).qrcode.modules
    size = 78
    cell = size.to_f / modules.length
    origin_x = 70
    origin_y = 70 + size

    doc.fill_color INK
    modules.each_with_index do |row, r|
      row.each_with_index do |dark, c|
        next unless dark
        doc.fill_rectangle [ origin_x + c * cell, origin_y - r * cell ], cell.ceil, cell.ceil
      end
    end

    host = URI.parse(@verify_url).host || @verify_url
    doc.font "Mono"
    doc.fill_color MUTED
    doc.text_box "Verify at\n#{host}", at: [ origin_x + size + 14, 70 + size - 20 ],
      width: 200, size: 10, leading: 3
    doc.fill_color INK
  end

  def centered(doc, y, text, font:, size:, style: :normal, color: INK, spacing: 0, width: nil, leading: 0)
    box_width = width || doc.bounds.width - 120
    doc.font font, style: style
    doc.fill_color color
    doc.character_spacing(spacing) do
      doc.text_box text.to_s,
        at: [ (doc.bounds.width - box_width) / 2, y ],
        width: box_width, size: size, align: :center, leading: leading
    end
    doc.fill_color INK
  end
end
