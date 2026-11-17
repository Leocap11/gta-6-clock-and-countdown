import sys
from pathlib import Path

from PIL import Image

LOGO_WIDTH_PER_SCREEN_HEIGHT = 310 / 1440
LOGO_MARGIN_PER_SCREEN_HEIGHT = 40 / 1440


def load_combined_logo(work_directory):
    logo = Image.open(work_directory / "logo-numeral.png").convert("RGBA")
    logo.alpha_composite(Image.open(work_directory / "logo-title.png").convert("RGBA"))
    return logo.crop(logo.getbbox())


def visible_area(artwork, screen_width, screen_height):
    zoom = max(screen_width / artwork.width, screen_height / artwork.height)
    visible_width = screen_width / zoom
    visible_height = screen_height / zoom
    left = (artwork.width - visible_width) / 2
    top = (artwork.height - visible_height) / 2
    return zoom, left, top, visible_width


def place_logo_in_top_right_corner(artwork, logo, screen_width, screen_height):
    zoom, visible_left, visible_top, visible_width = visible_area(artwork, screen_width, screen_height)
    logo_width = round(screen_height * LOGO_WIDTH_PER_SCREEN_HEIGHT / zoom)
    margin = screen_height * LOGO_MARGIN_PER_SCREEN_HEIGHT / zoom
    resized_logo = logo.resize((logo_width, round(logo.height * logo_width / logo.width)), Image.LANCZOS)
    logo_x = round(visible_left + visible_width - margin - logo_width)
    logo_y = round(visible_top + margin)
    artwork.alpha_composite(resized_logo, (logo_x, logo_y))


def main():
    work_directory = Path(sys.argv[1])
    wallpaper_file = Path(sys.argv[2])
    screen_width, screen_height = int(sys.argv[3]), int(sys.argv[4])
    artwork = Image.open(work_directory / "artwork.jpg").convert("RGBA")
    place_logo_in_top_right_corner(artwork, load_combined_logo(work_directory), screen_width, screen_height)
    artwork.convert("RGB").save(wallpaper_file, quality=95)


if __name__ == "__main__":
    main()
