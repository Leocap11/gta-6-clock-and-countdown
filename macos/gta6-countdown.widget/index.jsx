import { React } from "uebersicht";

export const refreshFrequency = false;

const RELEASE_MOMENT = new Date(2026, 10, 19, 0, 0, 0);
const MILLISECONDS_PER_SECOND = 1000;
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
const SECONDS_PER_DAY = 86400;
const WIDGET_FOLDER = "gta6-countdown.widget";
const POSITION_STORAGE_KEY = "gta6-countdown-position";
const DEFAULT_POSITION = { leftPercent: 12.35, topPercent: 48.6 };
const OUTLINE_COLOR = "#1d0231";
const OUTLINE_DIRECTIONS = 16;
const LOGO_CANVAS_SIZE = 1920;
const LOGO_VISIBLE_AREA = { x: 327, y: 532, width: 1107, height: 854 };
const LOGO_WIDTH_VH = 21.5;
const LOGO_MARGIN_VH = 2.78;
const UNIT_CAPTIONS = { days: "DAYS", hours: "HOURS", minutes: "MINUTES", seconds: "SECONDS" };
const WEEKDAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export const className = `
  position: absolute;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  pointer-events: none;
  font-family: Pricedown, "Pricedown Black", sans-serif;
  color: #ffffff;
  user-select: none;
`;

function outlineShadow(widthVh) {
  return Array.from({ length: OUTLINE_DIRECTIONS }, (unused, directionIndex) => {
    const angle = (directionIndex / OUTLINE_DIRECTIONS) * Math.PI * 2;
    return `${(Math.cos(angle) * widthVh).toFixed(3)}vh ${(Math.sin(angle) * widthVh).toFixed(3)}vh 0 ${OUTLINE_COLOR}`;
  }).join(", ");
}

const DIGITS_STYLE = { fontSize: "8.33vh", lineHeight: 1.1, textShadow: outlineShadow(0.28) };
const CAPTION_STYLE = { fontSize: "1.25vh", letterSpacing: "0.21vh", paddingTop: "0.7vh", textShadow: outlineShadow(0.14) };
const DATE_STYLE = { fontSize: "2.5vh", letterSpacing: "0.21vh", paddingTop: "0.7vh", textShadow: outlineShadow(0.14) };

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

function remainingSecondsUntilRelease(now) {
  return Math.max(0, Math.floor((RELEASE_MOMENT - now) / MILLISECONDS_PER_SECOND));
}

function formatClockTime(moment) {
  return [moment.getHours(), moment.getMinutes(), moment.getSeconds()].map(twoDigits).join(":");
}

function formatWeekdayAndDate(moment) {
  const date = [twoDigits(moment.getDate()), twoDigits(moment.getMonth() + 1), moment.getFullYear()].join("/");
  return `${WEEKDAY_NAMES[moment.getDay()]} ${date}`;
}

function loadSavedPosition() {
  try {
    return JSON.parse(localStorage.getItem(POSITION_STORAGE_KEY)) || DEFAULT_POSITION;
  } catch (error) {
    return DEFAULT_POSITION;
  }
}

function savePosition(position) {
  try {
    localStorage.setItem(POSITION_STORAGE_KEY, JSON.stringify(position));
  } catch (error) {}
}

function useCurrentTime() {
  const [now, setNow] = React.useState(new Date());
  React.useEffect(() => {
    const timerId = setInterval(() => setNow(new Date()), MILLISECONDS_PER_SECOND);
    return () => clearInterval(timerId);
  }, []);
  return now;
}

function useLockedDragging() {
  const [position, setPosition] = React.useState(loadSavedPosition);
  const [isUnlocked, setIsUnlocked] = React.useState(false);

  const toggleLock = () => setIsUnlocked((unlocked) => !unlocked);

  const startDragging = (pressEvent) => {
    if (!isUnlocked) return;
    pressEvent.preventDefault();
    const box = pressEvent.currentTarget.getBoundingClientRect();
    const grabOffsetX = pressEvent.clientX - box.left;
    const grabOffsetY = pressEvent.clientY - box.top;
    let latestPosition = position;
    const followPointer = (moveEvent) => {
      latestPosition = {
        leftPercent: ((moveEvent.clientX - grabOffsetX) / window.innerWidth) * 100,
        topPercent: ((moveEvent.clientY - grabOffsetY) / window.innerHeight) * 100,
      };
      setPosition(latestPosition);
    };
    const stopDragging = () => {
      window.removeEventListener("mousemove", followPointer);
      window.removeEventListener("mouseup", stopDragging);
      savePosition(latestPosition);
      setIsUnlocked(false);
    };
    window.addEventListener("mousemove", followPointer);
    window.addEventListener("mouseup", stopDragging);
  };

  return { position, isUnlocked, toggleLock, startDragging };
}

function CountdownUnit({ value, caption }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", minWidth: "9.03vh" }}>
      <div style={DIGITS_STYLE}>{twoDigits(value)}</div>
      <div style={CAPTION_STYLE}>{caption}</div>
    </div>
  );
}

function Countdown({ remainingSeconds }) {
  const remainingTime = splitRemainingTime(remainingSeconds);
  return (
    <div style={{ display: "flex", gap: "2.64vh" }}>
      {Object.keys(UNIT_CAPTIONS).map((unitName) => (
        <CountdownUnit key={unitName} value={remainingTime[unitName]} caption={UNIT_CAPTIONS[unitName]} />
      ))}
    </div>
  );
}

function Clock({ now }) {
  return (
    <div>
      <div style={DIGITS_STYLE}>{formatClockTime(now)}</div>
      <div style={DATE_STYLE}>{formatWeekdayAndDate(now)}</div>
    </div>
  );
}

function Logo() {
  const heightVh = (LOGO_WIDTH_VH * LOGO_VISIBLE_AREA.height) / LOGO_VISIBLE_AREA.width;
  const backgroundScale = (LOGO_CANVAS_SIZE / LOGO_VISIBLE_AREA.width) * 100;
  const horizontalOffset = (LOGO_VISIBLE_AREA.x / (LOGO_CANVAS_SIZE - LOGO_VISIBLE_AREA.width)) * 100;
  const verticalOffset = (LOGO_VISIBLE_AREA.y / (LOGO_CANVAS_SIZE - LOGO_VISIBLE_AREA.height)) * 100;
  return (
    <div
      style={{
        position: "absolute",
        top: `${LOGO_MARGIN_VH}vh`,
        right: `${LOGO_MARGIN_VH}vh`,
        width: `${LOGO_WIDTH_VH}vh`,
        height: `${heightVh}vh`,
        backgroundImage: `url("${WIDGET_FOLDER}/logo-title.png"), url("${WIDGET_FOLDER}/logo-numeral.png")`,
        backgroundSize: `${backgroundScale}% auto`,
        backgroundPosition: `${horizontalOffset}% ${verticalOffset}%`,
        backgroundRepeat: "no-repeat",
      }}
    />
  );
}

function CountdownWidget() {
  const now = useCurrentTime();
  const { position, isUnlocked, toggleLock, startDragging } = useLockedDragging();
  const remainingSeconds = remainingSecondsUntilRelease(now);
  return (
    <div>
      <Logo />
      <div
        onDoubleClick={toggleLock}
        onMouseDown={startDragging}
        style={{
          position: "absolute",
          left: `${position.leftPercent}vw`,
          top: `${position.topPercent}vh`,
          padding: "0.7vh 1vh",
          borderRadius: "0.8vh",
          pointerEvents: "auto",
          cursor: isUnlocked ? "move" : "default",
          border: isUnlocked ? "2px dashed rgba(255, 255, 255, 0.7)" : "2px solid transparent",
          background: isUnlocked ? "rgba(20, 8, 40, 0.35)" : "transparent",
        }}
      >
        {remainingSeconds > 0 ? <Countdown remainingSeconds={remainingSeconds} /> : <Clock now={now} />}
      </div>
    </div>
  );
}

export const render = () => <CountdownWidget />;
