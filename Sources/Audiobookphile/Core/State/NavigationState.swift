import Foundation
import Observation

/// Manages global UI presentation and routing state.
@Observable
@MainActor
public class NavigationState {
    public static let shared = NavigationState()
    
    public var showingSettings = false
    public var showingStats = false
    public var showingAccount = false
    public var showingConnectModal = false
    
    public var selectedTab = 0
    
    public init() {}
}
