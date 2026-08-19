//import SwiftUI
//
//struct StatsView: View {
//    @StateObject private var credentials = CredentialsStore()
//
//    var body: some View {
//        NavigationSplitView {
//            List {
//                NavigationLink("Credentials") { CredentialsView(credentials: credentials) }
//                NavigationLink("Apps") { AppsListView(credentials: credentials) }
//            }
//            .navigationTitle("App Store Stats")
//            .frame(minWidth: 200)
//        } detail: {
//            if credentials.isComplete {
//                AppsListView(credentials: credentials)
//            } else {
//                CredentialsView(credentials: credentials)
//            }
//        }
//    }
//}
