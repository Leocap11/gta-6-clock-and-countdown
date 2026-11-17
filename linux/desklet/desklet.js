const Desklet = imports.ui.desklet;
const St = imports.gi.St;
const Mainloop = imports.mainloop;
const Clutter = imports.gi.Clutter;
const Pango = imports.gi.Pango;
const Main = imports.ui.main;

const RELEASE_MOMENT = new Date(2026, 10, 19, 0, 0, 0);
const MILLISECONDS_PER_SECOND = 1000;
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
const SECONDS_PER_DAY = 86400;
const DESIGN_SCREEN_HEIGHT = 1440;
const SCREEN_SCALE = Main.layoutManager.primaryMonitor.height / DESIGN_SCREEN_HEIGHT;

function scaled(pixels) {
    return Math.max(1, Math.round(pixels * SCREEN_SCALE));
}

const LOGO_FONT = "font-family: Pricedown; ";
const OUTLINE_COLOR = "#1d0231";
const OUTLINE_DIRECTIONS = 16;
const DIGITS_TEXT = { size: scaled(120), outlineWidth: scaled(4), extraStyle: "" };
const CAPTION_TEXT = { size: scaled(18), outlineWidth: scaled(2), extraStyle: "letter-spacing: " + scaled(3) + "px; padding-top: " + scaled(10) + "px; " };
const DATE_TEXT = { size: scaled(36), outlineWidth: scaled(2), extraStyle: "letter-spacing: " + scaled(3) + "px; padding-top: " + scaled(10) + "px; " };
const UNIT_CAPTIONS = { days: "DAYS", hours: "HOURS", minutes: "MINUTES", seconds: "SECONDS" };
const UNLOCKED_STYLE = "border: 2px dashed rgba(255, 255, 255, 0.7); border-radius: 12px; background-color: rgba(20, 8, 40, 0.35);";
const LOCKED_STYLE = "border: 2px solid transparent;";
const DOUBLE_CLICK = 2;
const WEEKDAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function twoDigits(value) {
    return String(value).padStart(2, "0");
}

function splitRemainingTime(totalSeconds) {
    return {
        days: Math.floor(totalSeconds / SECONDS_PER_DAY),
        hours: Math.floor((totalSeconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR),
        minutes: Math.floor((totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE),
        seconds: totalSeconds % SECONDS_PER_MINUTE,
    };
}

function remainingSecondsUntilRelease() {
    return Math.max(0, Math.floor((RELEASE_MOMENT - Date.now()) / MILLISECONDS_PER_SECOND));
}

function formatClockTime(moment) {
    return [moment.getHours(), moment.getMinutes(), moment.getSeconds()].map(twoDigits).join(":");
}

function formatWeekdayAndDate(moment) {
    const date = [twoDigits(moment.getDate()), twoDigits(moment.getMonth() + 1), moment.getFullYear()].join("/");
    return WEEKDAY_NAMES[moment.getDay()] + " " + date;
}

function textStyle(textKind, color) {
    return LOGO_FONT + "color: " + color + "; font-size: " + textKind.size + "px; " + textKind.extraStyle;
}

function createPlainLabel(text, style) {
    const label = new St.Label({ text: text, style: style });
    label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
    return label;
}

function createOutlineCopy(text, textKind, directionIndex) {
    const angle = (directionIndex / OUTLINE_DIRECTIONS) * Math.PI * 2;
    const copy = createPlainLabel(text, textStyle(textKind, OUTLINE_COLOR));
    copy.translation_x = Math.round(Math.cos(angle) * textKind.outlineWidth);
    copy.translation_y = Math.round(Math.sin(angle) * textKind.outlineWidth);
    return copy;
}

class OutlinedLabel {
    constructor(text, textKind) {
        this.actor = new St.Widget({ layout_manager: new Clutter.BinLayout(), x_align: Clutter.ActorAlign.CENTER });
        this.labels = [];
        for (let directionIndex = 0; directionIndex < OUTLINE_DIRECTIONS; directionIndex++) {
            this.addLayer(createOutlineCopy(text, textKind, directionIndex));
        }
        this.addLayer(createPlainLabel(text, textStyle(textKind, "#ffffff")));
    }

    addLayer(label) {
        this.labels.push(label);
        this.actor.add_child(label);
    }

    setText(text) {
        for (const label of this.labels) label.set_text(text);
    }
}

class CountdownDesklet extends Desklet.Desklet {
    constructor(metadata, deskletId) {
        super(metadata, deskletId);
        this.container = new St.BoxLayout({ vertical: false });
        this.setContent(this.container);
        this.isShowingClock = false;
        this.actor.connect("button-press-event", (actor, event) => this.toggleLockOnDoubleClick(event));
        this._draggable.connect("drag-end", () => this.lockPosition());
        this.buildCountdown();
        this.refresh();
        this.timerId = Mainloop.timeout_add_seconds(1, () => this.refresh());
    }

    lockPosition() {
        this._draggable.inhibit = true;
        this.actor.set_style(LOCKED_STYLE);
    }

    unlockPosition() {
        this._draggable.inhibit = false;
        this.actor.set_style(UNLOCKED_STYLE);
    }

    toggleLockOnDoubleClick(event) {
        if (event.get_click_count() !== DOUBLE_CLICK) return Clutter.EVENT_PROPAGATE;
        if (this._draggable.inhibit) this.unlockPosition();
        else this.lockPosition();
        return Clutter.EVENT_STOP;
    }

    buildCountdown() {
        this.digitLabels = {};
        this.container.set_style("spacing: " + scaled(38) + "px;");
        for (const unitName of Object.keys(UNIT_CAPTIONS)) {
            this.container.add_child(this.createUnitColumn(unitName));
        }
    }

    createUnitColumn(unitName) {
        const column = new St.BoxLayout({ vertical: true, style: "min-width: " + scaled(130) + "px;" });
        const digitLabel = new OutlinedLabel("--", DIGITS_TEXT);
        column.add_child(digitLabel.actor);
        column.add_child(new OutlinedLabel(UNIT_CAPTIONS[unitName], CAPTION_TEXT).actor);
        this.digitLabels[unitName] = digitLabel;
        return column;
    }

    buildClock() {
        this.container.destroy_all_children();
        this.container.set_style("");
        const column = new St.BoxLayout({ vertical: true });
        this.clockLabel = new OutlinedLabel("", DIGITS_TEXT);
        this.dateLabel = new OutlinedLabel("", DATE_TEXT);
        this.clockLabel.actor.x_align = Clutter.ActorAlign.START;
        this.dateLabel.actor.x_align = Clutter.ActorAlign.START;
        column.add_child(this.clockLabel.actor);
        column.add_child(this.dateLabel.actor);
        this.container.add_child(column);
        this.isShowingClock = true;
    }

    showCountdown(remainingSeconds) {
        const remainingTime = splitRemainingTime(remainingSeconds);
        for (const unitName of Object.keys(this.digitLabels)) {
            this.digitLabels[unitName].setText(twoDigits(remainingTime[unitName]));
        }
    }

    showClock() {
        const now = new Date();
        this.clockLabel.setText(formatClockTime(now));
        this.dateLabel.setText(formatWeekdayAndDate(now));
    }

    refresh() {
        const remainingSeconds = remainingSecondsUntilRelease();
        if (remainingSeconds > 0) {
            this.showCountdown(remainingSeconds);
            return true;
        }
        if (!this.isShowingClock) this.buildClock();
        this.showClock();
        return true;
    }

    on_desklet_added_to_desktop() {
        this.lockPosition();
    }

    on_desklet_removed() {
        Mainloop.source_remove(this.timerId);
    }
}

function main(metadata, deskletId) {
    return new CountdownDesklet(metadata, deskletId);
}
