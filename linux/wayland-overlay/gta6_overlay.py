import json
import math
from datetime import datetime
from pathlib import Path

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("PangoCairo", "1.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell, Pango, PangoCairo

DATA_DIRECTORY = Path(__file__).resolve().parent
POSITION_FILE = DATA_DIRECTORY / "position.json"
RELEASE_MOMENT = datetime(2026, 11, 19, 0, 0, 0)
DESIGN_SCREEN_HEIGHT = 1440
DEFAULT_POSITION = {"horizontal": 0.1235, "vertical": 0.486}
LOGO_VISIBLE_AREA = (327, 532, 1107, 854)
LOGO_WIDTH_PER_SCREEN_HEIGHT = 310 / 1440
LOGO_MARGIN_PER_SCREEN_HEIGHT = 40 / 1440
OUTLINE_COLOR = (0x1D / 255, 0x02 / 255, 0x31 / 255)
UNIT_CAPTIONS = (("days", "DAYS"), ("hours", "HOURS"), ("minutes", "MINUTES"), ("seconds", "SECONDS"))
WEEKDAY_NAMES = ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
SECONDS_PER_DAY = 86400
SECONDS_PER_HOUR = 3600
SECONDS_PER_MINUTE = 60


def load_saved_position():
    try:
        return json.loads(POSITION_FILE.read_text())
    except (OSError, ValueError):
        return DEFAULT_POSITION


def save_position(position):
    POSITION_FILE.write_text(json.dumps(position))


def remaining_seconds_until_release():
    return max(0, math.floor((RELEASE_MOMENT - datetime.now()).total_seconds()))


def split_remaining_time(total_seconds):
    return {
        "days": total_seconds // SECONDS_PER_DAY,
        "hours": (total_seconds % SECONDS_PER_DAY) // SECONDS_PER_HOUR,
        "minutes": (total_seconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE,
        "seconds": total_seconds % SECONDS_PER_MINUTE,
    }


def format_weekday_and_date(moment):
    return f"{WEEKDAY_NAMES[moment.weekday()]} {moment.strftime('%d/%m/%Y')}"


def create_text_layout(context, text, font_size, letter_spacing):
    layout = PangoCairo.create_layout(context)
    font_description = Pango.FontDescription.from_string("Pricedown")
    font_description.set_absolute_size(font_size * Pango.SCALE)
    layout.set_font_description(font_description)
    attributes = Pango.AttrList()
    attributes.insert(Pango.attr_letter_spacing_new(int(letter_spacing * Pango.SCALE)))
    layout.set_attributes(attributes)
    layout.set_text(text, -1)
    return layout


def measure_text(context, text, font_size, letter_spacing=0):
    return create_text_layout(context, text, font_size, letter_spacing).get_pixel_size()


def draw_outlined_text(context, text, font_size, outline_width, x, y, letter_spacing=0):
    layout = create_text_layout(context, text, font_size, letter_spacing)
    context.move_to(x, y)
    PangoCairo.layout_path(context, layout)
    context.set_line_join(cairo.LINE_JOIN_ROUND)
    context.set_line_width(outline_width * 2)
    context.set_source_rgb(*OUTLINE_COLOR)
    context.stroke_preserve()
    context.set_source_rgb(1, 1, 1)
    context.fill()


class WallpaperRenderer:
    def __init__(self):
        self.artwork = GdkPixbuf.Pixbuf.new_from_file(str(DATA_DIRECTORY / "artwork.jpg"))
        self.logo_layers = [
            GdkPixbuf.Pixbuf.new_from_file(str(DATA_DIRECTORY / "logo-numeral.png")),
            GdkPixbuf.Pixbuf.new_from_file(str(DATA_DIRECTORY / "logo-title.png")),
        ]

    def render(self, context, width, height):
        self.draw_artwork(context, width, height)
        self.draw_logo(context, width, height)

    def draw_artwork(self, context, width, height):
        zoom = max(width / self.artwork.get_width(), height / self.artwork.get_height())
        context.save()
        context.translate((width - self.artwork.get_width() * zoom) / 2, (height - self.artwork.get_height() * zoom) / 2)
        context.scale(zoom, zoom)
        Gdk.cairo_set_source_pixbuf(context, self.artwork, 0, 0)
        context.paint()
        context.restore()

    def draw_logo(self, context, width, height):
        area_x, area_y, area_width, area_height = LOGO_VISIBLE_AREA
        logo_width = height * LOGO_WIDTH_PER_SCREEN_HEIGHT
        margin = height * LOGO_MARGIN_PER_SCREEN_HEIGHT
        logo_scale = logo_width / area_width
        context.save()
        context.translate(width - margin - logo_width, margin)
        context.scale(logo_scale, logo_scale)
        context.translate(-area_x, -area_y)
        context.rectangle(area_x, area_y, area_width, area_height)
        context.clip()
        for layer in self.logo_layers:
            Gdk.cairo_set_source_pixbuf(context, layer, 0, 0)
            context.paint()
        context.restore()


class CountdownRenderer:
    def __init__(self, screen_height):
        self.scale = screen_height / DESIGN_SCREEN_HEIGHT

    def scaled(self, pixels):
        return max(1, round(pixels * self.scale))

    def render(self, context, x, y):
        remaining_seconds = remaining_seconds_until_release()
        if remaining_seconds > 0:
            return self.draw_countdown(context, x, y, split_remaining_time(remaining_seconds))
        return self.draw_clock(context, x, y, datetime.now())

    def draw_countdown(self, context, x, y, remaining_time):
        digit_size, caption_size = self.scaled(120), self.scaled(18)
        caption_spacing = self.scaled(3)
        column_x = x
        total_height = 0
        for unit_name, caption in UNIT_CAPTIONS:
            digits = f"{remaining_time[unit_name]:02d}"
            digits_width, digits_height = measure_text(context, digits, digit_size)
            caption_width, caption_height = measure_text(context, caption, caption_size, caption_spacing)
            column_width = max(self.scaled(130), digits_width, caption_width)
            draw_outlined_text(context, digits, digit_size, self.scaled(4), column_x + (column_width - digits_width) / 2, y)
            caption_y = y + digits_height + self.scaled(10)
            draw_outlined_text(context, caption, caption_size, self.scaled(2), column_x + (column_width - caption_width) / 2, caption_y, caption_spacing)
            total_height = max(total_height, digits_height + self.scaled(10) + caption_height)
            column_x += column_width + self.scaled(38)
        return (x, y, column_x - self.scaled(38) - x, total_height)

    def draw_clock(self, context, x, y, now):
        time_text = now.strftime("%H:%M:%S")
        date_text = format_weekday_and_date(now)
        time_width, time_height = measure_text(context, time_text, self.scaled(120))
        date_width, date_height = measure_text(context, date_text, self.scaled(36), self.scaled(3))
        draw_outlined_text(context, time_text, self.scaled(120), self.scaled(4), x, y)
        draw_outlined_text(context, date_text, self.scaled(36), self.scaled(2), x, y + time_height + self.scaled(10), self.scaled(3))
        return (x, y, max(time_width, date_width), time_height + self.scaled(10) + date_height)


class DesktopOverlay:
    def __init__(self):
        self.window = Gtk.Window()
        self.configure_layer_surface()
        self.drawing_area = Gtk.DrawingArea()
        self.drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK)
        self.drawing_area.connect("draw", self.on_draw)
        self.drawing_area.connect("size-allocate", self.on_resize)
        self.drawing_area.connect("button-press-event", self.on_press)
        self.drawing_area.connect("motion-notify-event", self.on_motion)
        self.drawing_area.connect("button-release-event", self.on_release)
        self.window.add(self.drawing_area)
        self.wallpaper_renderer = WallpaperRenderer()
        self.wallpaper_cache = None
        self.countdown_renderer = None
        self.countdown_bounds = (0, 0, 0, 0)
        self.position = load_saved_position()
        self.is_locked = True
        self.drag_offset = None
        self.window.connect("destroy", Gtk.main_quit)
        self.window.show_all()
        GLib.timeout_add_seconds(1, self.on_tick)

    def configure_layer_surface(self):
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "gta6-countdown")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.BOTTOM)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self.window, edge, True)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)

    def on_resize(self, widget, allocation):
        self.wallpaper_cache = None
        self.countdown_renderer = CountdownRenderer(allocation.height)

    def cached_wallpaper(self, width, height):
        if self.wallpaper_cache is None:
            self.wallpaper_cache = cairo.ImageSurface(cairo.FORMAT_RGB24, width, height)
            self.wallpaper_renderer.render(cairo.Context(self.wallpaper_cache), width, height)
        return self.wallpaper_cache

    def countdown_origin(self, width, height):
        return (round(width * self.position["horizontal"]), round(height * self.position["vertical"]))

    def on_draw(self, widget, context):
        width, height = widget.get_allocated_width(), widget.get_allocated_height()
        context.set_source_surface(self.cached_wallpaper(width, height), 0, 0)
        context.paint()
        x, y = self.countdown_origin(width, height)
        if not self.is_locked:
            self.draw_unlocked_frame(context)
        self.countdown_bounds = self.countdown_renderer.render(context, x, y)
        return True

    def draw_unlocked_frame(self, context):
        x, y, width, height = self.countdown_bounds
        padding = self.countdown_renderer.scaled(12)
        context.rectangle(x - padding, y - padding, width + padding * 2, height + padding * 2)
        context.set_source_rgba(20 / 255, 8 / 255, 40 / 255, 0.35)
        context.fill_preserve()
        context.set_dash([8, 6])
        context.set_line_width(2)
        context.set_source_rgba(1, 1, 1, 0.7)
        context.stroke()
        context.set_dash([])

    def is_on_countdown(self, event):
        x, y, width, height = self.countdown_bounds
        return x <= event.x <= x + width and y <= event.y <= y + height

    def on_press(self, widget, event):
        if not self.is_on_countdown(event):
            return False
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            self.is_locked = not self.is_locked
            self.drag_offset = None
            widget.queue_draw()
        elif not self.is_locked:
            self.drag_offset = (event.x - self.countdown_bounds[0], event.y - self.countdown_bounds[1])
        return True

    def on_motion(self, widget, event):
        if self.drag_offset is None:
            return False
        width, height = widget.get_allocated_width(), widget.get_allocated_height()
        self.position = {
            "horizontal": (event.x - self.drag_offset[0]) / width,
            "vertical": (event.y - self.drag_offset[1]) / height,
        }
        widget.queue_draw()
        return True

    def on_release(self, widget, event):
        if self.drag_offset is None:
            return False
        self.drag_offset = None
        self.is_locked = True
        save_position(self.position)
        widget.queue_draw()
        return True

    def on_tick(self):
        self.drawing_area.queue_draw()
        return True


if __name__ == "__main__":
    DesktopOverlay()
    Gtk.main()
