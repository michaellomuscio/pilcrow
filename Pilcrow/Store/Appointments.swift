//  Appointments.swift
//  Writing appointments, on your actual calendar.
//
//  This is the highest-evidence feature in the app. Gollwitzer & Sheeran's
//  meta-analysis puts implementation intentions — "if [situation], then I
//  will [behaviour]" — at around d = 0.65 across hundreds of studies. The
//  operative part is the *cue*: a time and a place, not a word target.
//
//  So an appointment names when, where, and which document, and opens
//  straight into it with the timer running.

import Foundation
import EventKit
import Observation

struct Appointment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var when: Date
    var minutes: Int = 30
    /// The place is half the cue. "The kitchen table" is a real answer.
    var place: String = ""
    var nodeID: UUID? = nil
    /// What you'll actually do — the "then I will" half.
    var intention: String = ""
    var weekly: Bool = false
    /// EKEvent identifier, when it made it to the calendar.
    var eventID: String = ""

    var isPast: Bool { when.addingTimeInterval(Double(minutes) * 60) < Date() }

    /// The full if–then sentence, which is the thing that does the work.
    func sentence(documentTitle: String?) -> String {
        let f = DateFormatter()
        f.dateFormat = weekly ? "EEEE 'at' h:mm a" : "EEEE d MMMM 'at' h:mm a"
        var s = "If it's \(f.string(from: when))"
        if !place.isEmpty { s += " and I'm at \(place)" }
        s += ", then I will write"
        if let documentTitle, !documentTitle.isEmpty { s += " \u{201C}\(documentTitle)\u{201D}" }
        if !intention.isEmpty { s += " \u{2014} \(intention)" }
        s += " for \(minutes) minutes."
        return s
    }
}

@Observable
@MainActor
final class AppointmentBook {

    private let store = EKEventStore()
    var authorised = false
    var lastError: String?

    var accessDescription: String {
        authorised
        ? "Appointments are written to your default calendar."
        : "Pilcrow needs calendar access to put writing appointments where you'll actually see them."
    }

    func refreshAuthorisation() {
        let s = EKEventStore.authorizationStatus(for: .event)
        authorised = (s == .fullAccess || s == .writeOnly)
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestWriteOnlyAccessToEvents()
            authorised = granted
            if !granted { lastError = "Calendar access was declined." }
        } catch {
            lastError = error.localizedDescription
            authorised = false
        }
    }

    /// Writes the appointment to the calendar. Returns the event id, or nil
    /// with `lastError` set.
    @discardableResult
    func add(_ appointment: Appointment, documentTitle: String?,
             bookTitle: String) -> String? {
        guard authorised else {
            lastError = "No calendar access yet."
            return nil
        }
        let event = EKEvent(eventStore: store)
        event.title = documentTitle.map { "Write \u{2014} \($0)" } ?? "Writing \u{2014} \(bookTitle)"
        event.startDate = appointment.when
        event.endDate = appointment.when.addingTimeInterval(Double(appointment.minutes) * 60)
        event.location = appointment.place.isEmpty ? nil : appointment.place
        event.notes = appointment.sentence(documentTitle: documentTitle)
        event.calendar = store.defaultCalendarForNewEvents
        if appointment.weekly {
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly,
                                                      interval: 1, end: nil)]
        }
        let alarm = EKAlarm(relativeOffset: -300)   // five minutes' warning
        event.addAlarm(alarm)
        do {
            try store.save(event, span: appointment.weekly ? .futureEvents : .thisEvent)
            lastError = nil
            return event.eventIdentifier
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func remove(eventID: String) {
        guard authorised, !eventID.isEmpty,
              let event = store.event(withIdentifier: eventID) else { return }
        try? store.remove(event, span: .futureEvents)
    }
}
