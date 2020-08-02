//
//  AssignmentController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 02.11.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL

class AssignmentController: InstanceControllerDelegate {

    public static var global = AssignmentController()

    private var assignmentsLock = Threading.Lock()
    private var assignments = [Assignment]()
    private var isSetup = false
    private var queue: ThreadQueue!
    private var timeZone: TimeZone!

    private init() {}

    // swiftlint:disable:next function_body_length
	public func setup() throws {

        assignmentsLock.lock()
        assignments = try Assignment.getAll()
        assignmentsLock.unlock()

        timeZone = Localizer.global.timeZone

        if !isSetup {
            isSetup = true

            queue = Threading.getQueue(name: "AssignmentController-updater", type: .serial)
            queue.dispatch {

                let mysql = DBController.global.mysql

                var lastUpdate: Int32 = -2
				let lastUpdatedFile = File("\(projectroot)/backups/last-updated.txt")
                if lastUpdatedFile.exists {
                    do {
                        try lastUpdatedFile.open(.read)
                        if let contents = try lastUpdatedFile.readString().toInt32() {
                            lastUpdate = contents
                        }
                        lastUpdatedFile.close()
                    } catch {
                        Log.error(message: "Failed to read last updated from file: \(error.localizedDescription)")
                    }
                }

                while true {

                    let now = self.todaySeconds()
                    if lastUpdate == -2 {
                        Threading.sleep(seconds: 5)
                        lastUpdate = Int32(now)
                        continue
                    } else if lastUpdate > now {
                        lastUpdate = -1
                    }

                    self.assignmentsLock.lock()
                    let assignments = self.assignments
                    self.assignmentsLock.unlock()

                    for assignment in assignments {

                        if assignment.time != 0 &&
                           now >= assignment.time &&
                           lastUpdate < assignment.time {
                            self.triggerAssignment(mysql: mysql, assignment: assignment)
                        }

                    }

                    Threading.sleep(seconds: 5)
                    lastUpdate = Int32(now)
					do {
                        try lastUpdatedFile.open(.write)
                        try lastUpdatedFile.write(string: lastUpdate.toString())
                        lastUpdatedFile.close()
                    } catch {
                        Log.error(message: "Failed to store last updated to file: \(error.localizedDescription)")
                    }
                }

            }
        }

    }

    public func addAssignment(assignment: Assignment) {
        assignmentsLock.lock()
        assignments.append(assignment)
        assignmentsLock.unlock()
    }

    public func editAssignment(oldAssignment: Assignment, newAssignment: Assignment) {
        assignmentsLock.lock()
        if let index = assignments.index(of: oldAssignment) {
            assignments.remove(at: index)
        }
        assignments.append(newAssignment)
        assignmentsLock.unlock()
    }

    public func deleteAssignment(id: UInt32) {
        assignmentsLock.lock()
        assignments = assignments.filter({ $0.id != id })
        assignmentsLock.unlock()
    }

    public func triggerAssignment(mysql: MySQL?=nil, assignment: Assignment, force: Bool=false) {
		guard force || (
            assignment.enabled && (assignment.date == nil || assignment.date!.toString() == Date().toString())
        ) else {
			return
		}	
        var devices = [Device]()
        if let deviceUUID = assignment.deviceUUID {
            var done = false
            while !done {
                do {
                    if let device = try Device.getById(mysql: mysql, id: deviceUUID) {
                        devices.append(device)
                    }
                    done = true
                } catch {
                    Threading.sleep(seconds: 1.0)
                }
            }
        }
        if let deviceGroupName = assignment.deviceGroupName {
            var done = false
            while !done {
                do {
                    devices += try Device.getAllInGroup(mysql: mysql, deviceGroupName: deviceGroupName)
                    done = true
                } catch {
                    Threading.sleep(seconds: 1.0)
                }
            }
        }
        for device in devices where (
            force || (
                device.instanceName != assignment.instanceName &&
                (assignment.sourceInstanceName == nil || assignment.sourceInstanceName! == device.instanceName)
            )
        ) {
            Log.info(
                message: "[AssignmentController] Assigning \(device.uuid) to \(assignment.instanceName)"
            )
            InstanceController.global.removeDevice(device: device)
            device.instanceName = assignment.instanceName
            var done = false
            while !done {
                do {
                    try device.save(mysql: mysql, oldUUID: device.uuid)
                    done = true
                } catch {
                    Threading.sleep(seconds: 1.0)
                }
            }
            InstanceController.global.addDevice(device: device)
        }
    }

    private func todaySeconds() -> UInt32 {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = timeZone
        let formattedDate = formatter.string(from: date)

        let split = formattedDate.components(separatedBy: ":")
        if split.count >= 3 {
            let hour = UInt32(split[0]) ?? 0
            let minute = UInt32(split[1]) ?? 0
            let second = UInt32(split[2]) ?? 0
            return hour * 3600 + minute * 60 + second
        } else {
            return 0
        }
    }

    deinit {
        Threading.destroyQueue(queue)
    }

    // MARK: - InstanceControllerDelegate

    public func instanceControllerDone(mysql: MySQL?, name: String) {
                for assignment in assignments where (
            assignment.time == 0 && (assignment.sourceInstanceName == nil || assignment.sourceInstanceName == name)
        ) {
            triggerAssignment(mysql: mysql, assignment: assignment)
        }
    }
}