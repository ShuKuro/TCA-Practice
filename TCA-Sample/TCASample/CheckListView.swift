//
//  CheckListView.swift
//  Combine-Practice
//
//  Created by Shuhei Kuroda on 2022/02/26.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct CheckListState: Equatable {
  var alert: AlertState<CheckListAction>?
  var checks: IdentifiedArrayOf<CheckState> = []
  var selectedCount = 0
  var isShowModal = false
  
  var header = HeaderState()
}

enum CheckListAction: Equatable {
  case onAppear
  case check(index: UUID, action: CheckRowAction)
  case addButtonTapped
  case updateCountButton
  case fetchCheckResponse(Result<[Check], ProviderError>)
  case starButtonTapped
  case header(HeaderAction)
  case showAlert
  case add
  case alertDismissed
}

struct CheckListEnvironment {
  var checkListClient: CheckListClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID
}

let checkListReducer = Reducer<CheckListState, CheckListAction, CheckListEnvironment>.combine(
  checkRowReducer.forEach(
    state: \.checks,
    action: /CheckListAction.check(index:action:),
    environment: { _ in CheckRowEnvironment() }
  ), Reducer { state, action, environment in
    switch action {
    case .onAppear:
      return environment.checkListClient.fetch()
        .receive(on: environment.mainQueue)
        .catchToEffect(CheckListAction.fetchCheckResponse)
      
    case .check(index: let index, action: let action):
      return Effect(value: .updateCountButton)
      
    case .addButtonTapped:
      // TODO: 追加画面実装
      return .none
      
    case .updateCountButton:
      state.selectedCount = state.checks.filter { $0.isChecked }.count
      return .none
      
    case .fetchCheckResponse(.success(let response)):
      let checks = IdentifiedArrayOf<CheckState>(
        uniqueElements: response.map {
          CheckState(
            id: environment.uuid(),
            isChecked: false,
            check: $0
          )
        }
      )
      state.checks = checks
      return .none
      
    case .fetchCheckResponse(.failure):
      return .none
      
    case .starButtonTapped:
      state.header.userIconImage = "star"
      return .none
      
    case .header(let action):
      switch action {
      case .showModal:
        state.isShowModal.toggle()
      default: break
      }
      return .none
      
    case .showAlert:
      state.alert = .init(
        title: .init("追加しますか？"),
        primaryButton: .cancel(.init("いいえ")),
        secondaryButton: .default(.init("追加"), action: .send(.add))
      )
      return .none
      
    case .add:
      return .none
      
    case .alertDismissed:
      return .none
    }
  },
  headerReducer
    .pullback(
      state: \CheckListState.header,
      action: /CheckListAction.header,
      environment: { _ in HeaderEnvironment(
        userClient: .live,
        mainQueue: .main
      ) }
    )
)

struct CheckListView: View {
  let store: Store<CheckListState, CheckListAction>
  
  var body: some View {
    
    WithViewStore(self.store) { viewStore in
      ZStack {
        ZStack(alignment: .bottomTrailing) {
          VStack {
            HeaderView(
              store: self.store.scope(state: \.header, action: CheckListAction.header)
            )
            
            List {
              ForEachStore(
                self.store.scope(state: \.checks, action: CheckListAction.check(index:action:)),
                content: CheckRowView.init(store:)
              )
            }
            .listStyle(.plain)
            
          }
          
          Button(action: {
            
            if viewStore.selectedCount < viewStore.checks.count {
              // ダイアログ
              viewStore.send(.showAlert)
              
            } else {
              // TODO: チェックを外す
              viewStore.send(.starButtonTapped)
            }
          }) {
            Group {
              if viewStore.selectedCount < viewStore.checks.count {
                Text(viewStore.selectedCount == 0 ? "+" : "\(viewStore.selectedCount)")
              } else {
                Image(systemName: "star.fill")
              }
            }
            .foregroundColor(.black)
            .font(.system(size: 20))
            .frame(width: 55, height: 55)
            .background(Color.yellow)
            .clipShape(Circle())
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 16))
          }
        }
        
        if viewStore.isShowModal {
          Text("Modal")
            .font(.system(size: 20))
            .frame(width: 300, height: 300)
            .background(Color.cyan)
            .cornerRadius(20)
        }
        
      }
      .onAppear {
        viewStore.send(.onAppear)
      }
      .navigationTitle("CheckList")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add") {
             viewStore.send(.addButtonTapped)
          }
        }
      }
    }
    .alert(
      self.store.scope(state: \.alert),
      dismiss: .alertDismissed
    )
  }
}

struct CheckListView_Previews: PreviewProvider {
    static var previews: some View {
        CheckListView(
          store: Store(
            initialState: CheckListState(),
            reducer: checkListReducer,
            environment: CheckListEnvironment(
              checkListClient: .mockPreview(),
              mainQueue: .main,
              uuid: UUID.init
            )
          )
        )
    }
}
