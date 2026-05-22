#!/usr/bin/env ruby
# Generates enigma_icon.ico — blue shield with lock
# Uses chunky_png for rendering, wraps in ICO format

require 'chunky_png'

SIZE = 64
OUT  = File.join(__dir__, 'enigma_icon.ico')

# ── Colors ──
BG       = ChunkyPNG::Color.rgba(0, 0, 0, 0)
ORANGE_D = ChunkyPNG::Color.from_hex('#EA580C')     # dark orange (shield fill)
ORANGE_M = ChunkyPNG::Color.from_hex('#F97316')     # medium orange (shield edge)
ORANGE_L = ChunkyPNG::Color.from_hex('#FDBA74')     # light orange (highlight)
WHITE    = ChunkyPNG::Color.from_hex('#FFFFFF')
GRAY_L   = ChunkyPNG::Color.from_hex('#9CA3AF')     # light gray (lock shackle)
GRAY_D   = ChunkyPNG::Color.from_hex('#1F2937')     # dark gray-black (lock body)

img = ChunkyPNG::Image.new(SIZE, SIZE, BG)

# ── Fill polygon (integer coords) ──
def fill_polygon(img, pts, color)
  ys = pts.map(&:last)
  min_y, max_y = ys.min, ys.max
  (min_y..max_y).each do |y|
    xs = []
    pts.each_cons(2) do |(x1, y1), (x2, y2)|
      next if y1 == y2
      next if y < [y1, y2].min || y >= [y1, y2].max
      x = x1 + (x2 - x1) * (y - y1).to_f / (y2 - y1)
      xs << x
    end
    x1, y1 = pts.last
    x2, y2 = pts.first
    if y1 != y2 && y >= [y1, y2].min && y < [y1, y2].max
      x = x1 + (x2 - x1) * (y - y1).to_f / (y2 - y1)
      xs << x
    end
    xs.sort!
    xs.each_slice(2) do |a, b|
      next unless b
      (a.ceil..b.floor).each do |x|
        img[x, y] = color if x.between?(0, img.width - 1)
      end
    end
  end
end

# ── Draw filled circle ──
def fill_circle(img, cx, cy, r, color)
  (-r..r).each do |dy|
    (-r..r).each do |dx|
      d2 = dx*dx + dy*dy
      next if d2 > r*r
      x, y = cx + dx, cy + dy
      img[x, y] = color if x.between?(0, img.width-1) && y.between?(0, img.height-1)
    end
  end
end

# ── Shield points (64x64 grid) ──
cx, cy = 32, 32
shield = [
  [12, 16],   # top-left flat
  [8,  22],   # left shoulder
  [10, 48],   # mid-left
  [32, 57],   # bottom point
  [54, 48],   # mid-right
  [56, 22],   # right shoulder
  [52, 16],   # top-right flat
]

# Shield border (1px larger)
shield_border = shield.map { |x, y| [x, y] }
shield_border[0] = [11, 15]
shield_border[1] = [7,  21]
shield_border[2] = [9,  49]
shield_border[3] = [32, 58]
shield_border[4] = [55, 49]
shield_border[5] = [57, 21]
shield_border[6] = [53, 15]

# Draw border first, then inner shield
fill_polygon(img, shield_border, ORANGE_M)
fill_polygon(img, shield, ORANGE_D)

# Highlight on left side
hl = [
  [14, 18],
  [11, 24],
  [13, 40],
  [20, 36],
  [18, 28],
  [14, 18],
]
fill_polygon(img, hl, ORANGE_L)

# ── Lock ──
lock_cx = cx
lock_body_top = 30
lock_body_bot = 48
lock_body_l = 16
lock_body_w = 14

# Lock body
(lock_body_top..lock_body_bot).each do |y|
  ((lock_cx - lock_body_w/2)..(lock_cx + lock_body_w/2 - 1)).each do |x|
    img[x, y] = GRAY_D if x.between?(0, 63) && y.between?(0, 63)
  end
end

# Keyhole
fill_circle(img, lock_cx, lock_body_top + 6, 3, WHITE)
(lock_body_top + 6..lock_body_top + 11).each do |y|
  ((lock_cx - 1)..(lock_cx + 1)).each do |x|
    img[x, y] = WHITE if x.between?(0, 63)
  end
end

# Lock shackle (arc)
sr = 7
sl = 5
scx = lock_cx
scy = lock_body_top - sr + 1

(-sr..sr).each do |dy|
  (-sr..sr).each do |dx|
    d2 = dx*dx + dy*dy
    next if d2 > sr*sr
    next if d2 < (sr - sl) * (sr - sl)
    x, y = scx + dx, scy + dy
    next unless x.between?(0, 63) && y.between?(0, 63)
    next if y >= lock_body_top  # stay above lock body
    # Don't overwrite shield edge
    px = img[x, y]
    next if px == ORANGE_D || px == ORANGE_M || px == ORANGE_L
    img[x, y] = GRAY_L
  end
end

# ── Save ICO ──
png_blob = img.to_blob(:fast_rgba)

File.open(OUT, 'wb') do |f|
  f.write([0, 0].pack('v'))    # reserved
  f.write([1].pack('v'))        # type: ICO
  f.write([1].pack('v'))        # count

  w = SIZE >= 256 ? 0 : SIZE
  h = SIZE >= 256 ? 0 : SIZE
  f.write([w, h].pack('CC'))    # width, height
  f.write([0, 0].pack('CC'))    # colors, reserved
  f.write([1, 32].pack('vv'))   # planes, bpp
  f.write([png_blob.bytesize].pack('V'))  # size
  f.write([22].pack('V'))       # offset

  f.write(png_blob)
end

puts "OK: #{OUT} (#{File.size(OUT)} bytes)"
