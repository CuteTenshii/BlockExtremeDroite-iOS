import Foundation

/// How to find one control on a platform's website: CSS selectors first, then exact accessible labels.
nonisolated struct Target {
    var selectors: [String] = []
    var labels: [String] = []

    var dictionary: [String: Any] { ["selectors": selectors, "labels": labels] }
}

/// Everything the injected script needs to drive one platform's website. When a site changes its markup,
/// its entry in `Platform.webSpec` is the place to update. Labels are lowercase, in French and English.
nonisolated struct WebSpec {
    var overflow: Target
    var block: Target
    var confirm: Target
    var unblock: Target
    var blockedProfile: Target
    var gate = Target()
    var loggedOut: Target
    var unavailableText: [String]
    var profileMarker: (Profile) -> String

    func dictionary(for profile: Profile) -> [String: Any] {
        [
            "marker": profileMarker(profile),
            "overflow": overflow.dictionary, "block": block.dictionary, "confirm": confirm.dictionary,
            "unblock": unblock.dictionary, "blockedProfile": blockedProfile.dictionary,
            "gate": gate.dictionary, "loggedOut": loggedOut.dictionary,
            "unavailable": unavailableText,
        ]
    }
}

nonisolated extension Platform {
    /// Nil for platforms whose website flow isn't implemented yet.
    var webSpec: WebSpec? {
        switch self {
        case .x:
            WebSpec(
                overflow: Target(selectors: [#"[data-testid="userActions"]"#], labels: ["plus d'options", "more options"]),
                block: Target(selectors: [#"[data-testid="block"]"#]),
                confirm: Target(selectors: [#"[data-testid="confirmationSheetConfirm"]"#]),
                unblock: Target(selectors: [#"[data-testid="unblock"]"#]),
                blockedProfile: Target(selectors: [#"[data-testid$="-unblock"]"#]),
                gate: Target(labels: ["oui, voir le profil", "voir le profil", "yes, view profile", "view profile"]),
                loggedOut: Target(selectors: [#"[data-testid="loginButton"]"#], labels: ["se connecter", "log in"]),
                unavailableText: ["ce compte n'existe pas", "compte suspendu", "this account doesn't exist", "account suspended"],
                profileMarker: { Self.boundary("@" + ($0.handle ?? "")) }
            )
        case .instagram:
            WebSpec(
                overflow: Target(labels: ["options"]),
                block: Target(labels: ["bloquer", "block"]),
                confirm: Target(labels: ["bloquer", "block"]),
                unblock: Target(labels: ["débloquer", "unblock"]),
                blockedProfile: Target(labels: ["débloquer", "unblock"]),
                loggedOut: Target(labels: ["se connecter", "log in"]),
                unavailableText: ["cette page n'est pas disponible", "this page isn't available", "utilisateur introuvable", "user not found"],
                profileMarker: { Self.boundary($0.handle ?? "") }
            )
        case .facebook:
            WebSpec(
                overflow: Target(labels: ["see options", "voir les options", "more profile settings", "autres paramètres du profil"]),
                block: Target(labels: ["block", "bloquer"]),
                confirm: Target(labels: ["confirm", "confirmer", "block", "bloquer"]),
                unblock: Target(labels: ["unblock", "débloquer"]),
                blockedProfile: Target(labels: ["unblock", "débloquer"]),
                loggedOut: Target(labels: ["log in", "se connecter"]),
                unavailableText: ["this content isn't available", "ce contenu n'est pas disponible"],
                profileMarker: { _ in "." }
            )
        case .tiktok:
            WebSpec(
                overflow: Target(selectors: [#"[data-e2e="user-more"]"#], labels: ["more actions", "plus d'actions"]),
                block: Target(labels: ["block", "bloquer"]),
                confirm: Target(labels: ["block", "bloquer"]),
                unblock: Target(labels: ["unblock", "débloquer"]),
                blockedProfile: Target(labels: ["unblock", "débloquer"]),
                loggedOut: Target(selectors: [#"[data-e2e="top-login-button"]"#], labels: ["log in", "se connecter"]),
                unavailableText: ["couldn't find this account", "impossible de trouver ce compte"],
                profileMarker: { Self.boundary("@" + ($0.handle ?? "")) }
            )
        case .youtube:
            nil
        }
    }

    /// The cookie that exists only while signed in to the website.
    var sessionCookie: (domain: String, name: String)? {
        switch self {
        case .x: ("x.com", "auth_token")
        case .instagram: ("instagram.com", "sessionid")
        case .facebook: ("facebook.com", "c_user")
        case .tiktok: ("tiktok.com", "sessionid")
        case .youtube: nil
        }
    }

    private static func boundary(_ handle: String) -> String {
        "(^|[^a-z0-9_.])" + NSRegularExpression.escapedPattern(for: handle.lowercased()) + "($|[^a-z0-9_.])"
    }
}
