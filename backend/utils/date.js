function toUtcDay(value) {
    if (value === null || value === undefined || value === '') {
        return Number.NaN;
    }

    if (value instanceof Date) {
        return Date.UTC(
            value.getUTCFullYear(),
            value.getUTCMonth(),
            value.getUTCDate()
        );
    }

    if (typeof value === 'string') {
        const trimmed = value.trim();

        const isoMatch = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(trimmed);
        if (isoMatch) {
            const [, year, month, day] = isoMatch;
            return Date.UTC(Number(year), Number(month) - 1, Number(day));
        }

        const asDate = new Date(trimmed);
        if (!Number.isNaN(asDate.getTime())) {
            return Date.UTC(
                asDate.getUTCFullYear(),
                asDate.getUTCMonth(),
                asDate.getUTCDate()
            );
        }
    }

    const asDate = new Date(value);
    if (Number.isNaN(asDate.getTime())) {
        return Number.NaN;
    }

    return Date.UTC(
        asDate.getUTCFullYear(),
        asDate.getUTCMonth(),
        asDate.getUTCDate()
    );
}

function daysBetween(startDate, endDate) {
    const startUtc = toUtcDay(startDate);
    const endUtc = toUtcDay(endDate);

    if (Number.isNaN(startUtc) || Number.isNaN(endUtc)) {
        return Number.NaN;
    }

    return Math.floor((endUtc - startUtc) / 86400000);
}

function formatDateYmd(date) {
    const d = date instanceof Date ? date : new Date(date);
    if (Number.isNaN(d.getTime())) {
        return null;
    }

    const year = d.getUTCFullYear();
    const month = String(d.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d.getUTCDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function todayInThailand() {
    const formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Bangkok',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
    });

    const parts = formatter.formatToParts(new Date());
    const map = {};
    for (const part of parts) {
        if (part.type !== 'literal') {
            map[part.type] = part.value;
        }
    }

    return `${map.year}-${map.month}-${map.day}`;
}

function addDays(date, days) {
    const base = date instanceof Date ? new Date(date.getTime()) : new Date(date);
    if (Number.isNaN(base.getTime())) {
        return null;
    }

    base.setUTCDate(base.getUTCDate() + Number(days || 0));
    return formatDateYmd(base);
}

module.exports = {
    toUtcDay,
    daysBetween,
    formatDateYmd,
    todayInThailand,
    addDays
};
