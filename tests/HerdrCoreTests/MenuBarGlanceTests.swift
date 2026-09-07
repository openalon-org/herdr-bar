import Foundation
import Testing
@testable import HerdrCore

@Suite("Menu-bar extra is a glance")
struct MenuBarGlanceTests {
    @Test func offlineIsTheEmptyDot() {
        #expect(MenuBarGlance.glanceableStatuses([.done: 2, .working: 1, .blocked: 1], online: false).isEmpty)
        #expect(MenuBarGlance.preferredWidth(counts: [.done: 2], online: false) == MenuBarGlance.emptyWidth)
    }

    @Test func idleNeverJoinsTheExtra() {
        let idleOnly: [AgentStatus: Int] = [.idle: 9]
        #expect(MenuBarGlance.glanceableStatuses(idleOnly, online: true) == [.done, .working])
        #expect(
            MenuBarGlance.preferredWidth(counts: idleOnly, online: true)
                == MenuBarGlance.preferredWidth(counts: [:], online: true)
        )
    }

    @Test func doneAndWorkingAreTheOnlineSkeleton() {
        #expect(MenuBarGlance.glanceableStatuses([:], online: true) == [.done, .working])
        let width = MenuBarGlance.preferredWidth(counts: [:], online: true)
        #expect(width > MenuBarGlance.emptyWidth)
        #expect(width == MenuBarGlance.preferredWidth(counts: [.done: 0, .working: 0], online: true))
    }

    @Test func blockedAndUnknownJoinOnlyWhenTheyNeedYou() {
        #expect(MenuBarGlance.glanceableStatuses([.blocked: 0, .unknown: 0], online: true) == [.done, .working])
        #expect(MenuBarGlance.glanceableStatuses([.blocked: 1], online: true) == [.blocked, .done, .working])
        #expect(MenuBarGlance.glanceableStatuses([.unknown: 2], online: true) == [.done, .working, .unknown])
        #expect(MenuBarGlance.glanceableStatuses([.blocked: 1, .unknown: 1], online: true) == AgentStatus.order.filter { $0 != .idle })
    }

    @Test func interruptWidensTheHousing() {
        let skeleton = MenuBarGlance.preferredWidth(counts: [:], online: true)
        let blocked = MenuBarGlance.preferredWidth(counts: [.blocked: 1], online: true)
        #expect(blocked > skeleton)
    }

    @Test func digitRolloverWidensTheHousing() {
        let nine = MenuBarGlance.preferredWidth(counts: [.done: 9], online: true)
        let ten = MenuBarGlance.preferredWidth(counts: [.done: 10], online: true)
        #expect(ten > nine)
        #expect(ten - nine == MenuBarGlance.digitWidth)
    }

    @Test func zerosDoNotShrinkASkeletonChip() {
        let live = MenuBarGlance.chipInnerWidth(status: .done, count: 3)
        let zero = MenuBarGlance.chipInnerWidth(status: .done, count: 0)
        #expect(live == zero)
        #expect(MenuBarGlance.chipInnerWidth(status: .working, count: 0) == MenuBarGlance.chipInnerWidth(status: .working, count: 1))
    }

    @Test func housingIsClusterPlusInsetNotAnIslandPad() {
        let cluster = MenuBarGlance.clusterWidth([:], online: true)
        let housing = MenuBarGlance.housingWidth([:], online: true)
        #expect(housing == cluster + MenuBarGlance.inset * 2)
        #expect(MenuBarGlance.inset == 4)
    }
}
