//
//  Router.swift
//  Blurrify
//
//  Created by Neftali Samarey on 10/22/26.
//

import Observation

@Observable
final class Router {
    var path: [Router] = []
    
    func push(for route: Router) {
        path.append(route)
    }
    
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeAll()
    }
}
