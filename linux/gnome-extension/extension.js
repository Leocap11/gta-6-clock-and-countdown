import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const RELEASE_MOMENT = new Date(2026, 10, 19, 0, 0, 0);
const MILLISECONDS_PER_SECOND = 1000;
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
const SECONDS_PER_DAY = 86400;
const DESIGN_SCREEN_HEIGHT = 1440;
const DEFAULT_POSITION = {horizontal: 0.1235, vertical: 0.486};
const POSITION_FILE = GLib.build_filenamev([GLib.get_user_data_dir(), 'gta6-countdown', 'posizione.json']);
const OUTLINE_COLOR = '#1d0231';
const OUTLINE_DIRECTIONS = 16;
const DOUBLE_CLICK = 2;
const UNIT_CAPTIONS = {days: 'DAYS', hours: 'HOURS', minutes: 'MINUTES', seconds: 'SECONDS'};
const WEEKDAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const UNLOCKED_STYLE = 'border: 2px dashed rgba(255, 255, 255, 0.7); border-radius: 12px; background-color: rgba(20, 8, 40, 0.35);';
const LOCKED_STYLE = 'border: 2px solid transparent;';

function screenScale() {
    return Main.layoutManager.primaryMonitor.height / DESIGN_SCREEN_HEIGHT;
}

function scaled(pixels) {
    return Math.max(1, Math.round(pixels * screenScale()));
}

function textKinds() {
    return {
        digits: {size: scaled(120), outlineWidth: scaled(4), extraStyle: ''},
        caption: {size: scaled(18), outlineWidth: scaled(2), extraStyle: `letter-spacing: ${scaled(3)}px; padding-top: ${scaled(10)}px; `},
        date: {size: scaled(36), outlineWidth: scaled(2), extraStyle: `letter-spacing: ${scaled(3)}px; padding-top: ${scaled(10)}px; `},
    };
}

function twoDigits(value) {
    return String(value).padStart(2, '0');
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
    return [moment.getHours(), moment.getMinutes(), moment.getSeconds()].map(twoDigits).join(':');
}

function formatWeekdayAndDate(moment) {
    const date = [twoDigits(moment.getDate()), twoDigits(moment.getMonth() + 1), moment.getFullYear()].join('/');
    return `${WEEKDAY_NAMES[moment.getDay()]} ${date}`;
}

function loadSavedPosition() {
    try {
        const [, contents] = GLib.file_get_contents(POSITION_FILE);
        return JSON.parse(new TextDecoder().decode(contents));
    } catch {
        return DEFAULT_POSITION;
    }
}

function savePosition(position) {
    GLib.mkdir_with_parents(GLib.path_get_dirname(POSITION_FILE), 0o755);
    GLib.file_set_contents(POSITION_FILE, JSON.stringify(position));
}

function textStyle(textKind, color) {
    return `font-family: Pricedown; color: ${color}; font-size: ${textKind.size}px; ${textKind.extraStyle}`;
}

function createPlainLabel(text, style) {
    const label = new St.Label({text, style});
    label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
    return label;
}

class OutlinedLabel {
    constructor(text, textKind) {
        this.actor = new St.Widget({layout_manager: new Clutter.BinLayout(), x_align: Clutter.ActorAlign.CENTER});
        this.labels = [];
        for (let directionIndex = 0; directionIndex < OUTLINE_DIRECTIONS; directionIndex++) {
            const angle = (directionIndex / OUTLINE_DIRECTIONS) * Math.PI * 2;
            const outlineCopy = createPlainLabel(text, textStyle(textKind, OUTLINE_COLOR));
            outlineCopy.translation_x = Math.round(Math.cos(angle) * textKind.outlineWidth);
            outlineCopy.translation_y = Math.round(Math.sin(angle) * textKind.outlineWidth);
            this.addLayer(outlineCopy);
        }
        this.addLayer(createPlainLabel(text, textStyle(textKind, '#ffffff')));
    }

    addLayer(label) {
        this.labels.push(label);
        this.actor.add_child(label);
    }

    setText(text) {
        for (const label of this.labels)
            label.set_text(text);
    }
}

class CountdownWidget {
    constructor() {
        this.textKinds = textKinds();
        this.isShowingClock = false;
        this.isLocked = true;
        this.actor = new St.BoxLayout({reactive: true, style: LOCKED_STYLE});
        this.actor.connect('button-press-event', (actor, event) => this.handlePress(event));
        this.actor.connect('motion-event', (actor, event) => this.followPointer(event));
        this.actor.connect('button-release-event', () => this.stopDragging());
        this.buildCountdown();
        this.moveToSavedPosition();
        this.refresh();
    }

    moveToSavedPosition() {
        const monitor = Main.layoutManager.primaryMonitor;
        const position = loadSavedPosition();
        this.actor.set_position(
            Math.round(monitor.x + monitor.width * position.horizontal),
            Math.round(monitor.y + monitor.height * position.vertical));
    }

    lockPosition() {
        this.isLocked = true;
        this.actor.set_style(LOCKED_STYLE);
    }

    unlockPosition() {
        this.isLocked = false;
        this.actor.set_style(UNLOCKED_STYLE);
    }

    handlePress(event) {
        if (event.get_click_count() === DOUBLE_CLICK) {
            if (this.isLocked)
                this.unlockPosition();
            else
                this.lockPosition();
            return Clutter.EVENT_STOP;
        }
        if (this.isLocked)
            return Clutter.EVENT_PROPAGATE;
        const [pointerX, pointerY] = event.get_coords();
        this.grabOffset = [pointerX - this.actor.x, pointerY - this.actor.y];
        this.grab = global.stage.grab(this.actor);
        return Clutter.EVENT_STOP;
    }

    followPointer(event) {
        if (!this.grab)
            return Clutter.EVENT_PROPAGATE;
        const [pointerX, pointerY] = event.get_coords();
        this.actor.set_position(Math.round(pointerX - this.grabOffset[0]), Math.round(pointerY - this.grabOffset[1]));
        return Clutter.EVENT_STOP;
    }

    stopDragging() {
        if (!this.grab)
            return Clutter.EVENT_PROPAGATE;
        this.grab.dismiss();
        this.grab = null;
        const monitor = Main.layoutManager.primaryMonitor;
        savePosition({
            horizontal: (this.actor.x - monitor.x) / monitor.width,
            vertical: (this.actor.y - monitor.y) / monitor.height,
        });
        this.lockPosition();
        return Clutter.EVENT_STOP;
    }

    buildCountdown() {
        this.digitLabels = {};
        this.actor.add_child(this.createCountdownRow());
    }

    createCountdownRow() {
        const row = new St.BoxLayout({style: `spacing: ${scaled(38)}px;`});
        for (const unitName of Object.keys(UNIT_CAPTIONS))
            row.add_child(this.createUnitColumn(unitName));
        return row;
    }

    createUnitColumn(unitName) {
        const column = new St.BoxLayout({vertical: true, style: `min-width: ${scaled(130)}px;`});
        const digitLabel = new OutlinedLabel('--', this.textKinds.digits);
        column.add_child(digitLabel.actor);
        column.add_child(new OutlinedLabel(UNIT_CAPTIONS[unitName], this.textKinds.caption).actor);
        this.digitLabels[unitName] = digitLabel;
        return column;
    }

    buildClock() {
        this.actor.destroy_all_children();
        const column = new St.BoxLayout({vertical: true});
        this.clockLabel = new OutlinedLabel('', this.textKinds.digits);
        this.dateLabel = new OutlinedLabel('', this.textKinds.date);
        this.clockLabel.actor.x_align = Clutter.ActorAlign.START;
        this.dateLabel.actor.x_align = Clutter.ActorAlign.START;
        column.add_child(this.clockLabel.actor);
        column.add_child(this.dateLabel.actor);
        this.actor.add_child(column);
        this.isShowingClock = true;
    }

    showCountdown(remainingSeconds) {
        const remainingTime = splitRemainingTime(remainingSeconds);
        for (const unitName of Object.keys(this.digitLabels))
            this.digitLabels[unitName].setText(twoDigits(remainingTime[unitName]));
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
            return;
        }
        if (!this.isShowingClock)
            this.buildClock();
        this.showClock();
    }

    destroy() {
        if (this.grab)
            this.grab.dismiss();
        this.actor.destroy();
    }
}

export default class GtaCountdownExtension extends Extension {
    enable() {
        this.countdownWidget = new CountdownWidget();
        Main.layoutManager._backgroundGroup.add_child(this.countdownWidget.actor);
        this.timerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this.countdownWidget.refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        GLib.source_remove(this.timerId);
        this.timerId = null;
        this.countdownWidget.destroy();
        this.countdownWidget = null;
    }
}
