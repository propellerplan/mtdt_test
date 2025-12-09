/**
 * Created on 30/12/2022.
 */

class TimeTrackerServices {
    static parseDuration(durationHours) {
        if (!durationHours) return 0;
        let duration = 0;
        durationHours = durationHours.toString();
        if (durationHours.indexOf(':') > -1) {
            const match = durationHours.match(/^(\d+):(\d+)$/);
            if (!match) return 0;
            const hours = parseInt(match[1]);
            const minutes = parseFloat(match[2]);
            duration = hours + minutes / 60;
        } else {
            duration = parseFloat(durationHours);
        }
        return Math.round((duration + Number.EPSILON) * 100) / 100;
    }
    static formatDuration(duration) {
        if (!duration) return '0:00';
        const hours = Math.trunc(duration);
        const minutes = (duration - hours) * 60;
        return hours + ':' + (minutes < 10 ? '0' : '') + Math.round(minutes);
    }
    static getMonday(d) {
        d = new Date(d);
        const day = d.getDay(),
            diff = d.getDate() - day + (day === 0 ? -6 : 1);
        return new Date(d.setDate(diff));
    }
    static addDays(d, days) {
        let date = new Date(d);
        date.setDate(date.getDate() + days);
        return date;
    }
    static addMonths(d, months) {
        let date = new Date(d);
        date.setMonth(date.getMonth() + months);
        return date;
    }
}

export {TimeTrackerServices}