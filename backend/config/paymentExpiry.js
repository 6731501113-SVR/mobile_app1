const borrowModel = require('../models/borrowModel');

let timerId = null;
const CHECK_INTERVAL_MS = 60 * 1000;

async function runCheck() {
    try {
        const cancelled = await borrowModel.cancelExpiredUnpaid();
        if (cancelled > 0) {
            console.log(`[paymentExpiry] Auto-cancelled ${cancelled} expired unpaid request(s).`);
        }
    } catch (error) {
        console.error('[paymentExpiry] Failed to auto-cancel expired unpaid requests:', error.message);
    }
}

function start() {
    if (timerId) {
        return timerId;
    }

    runCheck();
    timerId = setInterval(runCheck, CHECK_INTERVAL_MS);
    console.log(`[paymentExpiry] Monitoring payment deadlines every ${CHECK_INTERVAL_MS / 1000} seconds.`);
    return timerId;
}

function stop() {
    if (timerId) {
        clearInterval(timerId);
        timerId = null;
    }
}

module.exports = {
    start,
    stop,
    runCheck
};
