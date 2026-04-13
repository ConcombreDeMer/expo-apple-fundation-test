import ExpoModulesCore
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleAITaskRecord: Record {
  @Field var id: String = ""
  @Field var title: String = ""
  @Field var completed: Bool = false
  @Field var createdAt: Double = 0
}

public final class AppleAIExpoModule: Module {
  public func definition() -> ModuleDefinition {
    Name("AppleAIExpoModule")

    AsyncFunction("getAvailability") { () -> [String: Any?] in
      Self.currentAvailability()
    }

    AsyncFunction("isAvailable") { () -> Bool in
      (Self.currentAvailability()["isAvailable"] as? Bool) ?? false
    }

    AsyncFunction("generateText") { (prompt: String) async throws -> String in
      try await Self.generateText(prompt: prompt)
    }

    AsyncFunction("summarizeTasks") { (tasks: [AppleAITaskRecord]) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildSummaryPrompt(from: tasks),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("suggestPriorities") { (tasks: [AppleAITaskRecord]) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildPrioritiesPrompt(from: tasks),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("turnNotesIntoTasks") { (input: String) async throws -> [String] in
      try await Self.turnNotesIntoTasks(input: input)
    }

    AsyncFunction("rewriteTask") { (title: String) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildRewritePrompt(for: title),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("planAction") { (input: String, tasks: [AppleAITaskRecord]) async throws -> [String: Any?] in
      try await Self.planAction(input: input, tasks: tasks)
    }
  }

  private static let assistantInstructions = """
  Tu es un assistant local intégré à une app iPhone de to-do list.
  Réponds toujours en français.
  Sois naturel, chaleureux, clair et utile.
  Écris comme une vraie assistante personnelle, pas comme un système technique.
  Évite les formulations mécaniques, les libellés robotiques et les comptes-rendus rigides.
  Préfère des phrases fluides et humaines.
  Ne fais aucune mention d'un service cloud ou d'un backend.
  """

  private static func currentAvailability() -> [String: Any?] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      return [
        "isAvailable": false,
        "reason": "Foundation Models requiert iOS 26 ou plus."
      ]
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      return [
        "isAvailable": true,
        "reason": nil
      ]
    case .unavailable(let reason):
      return [
        "isAvailable": false,
        "reason": Self.message(for: reason)
      ]
    }
#else
    return [
      "isAvailable": false,
      "reason": "Le framework Foundation Models n'est pas disponible avec cette version de Xcode."
    ]
#endif
  }

  private static func asExpoException(_ error: Error) -> Exception {
    if let exception = error as? Exception {
      return exception
    }

    return Exception(
      name: "ERR_APPLE_AI",
      description: Self.message(for: error),
      code: "ERR_APPLE_AI"
    )
  }

  private static func generateText(prompt: String, instructions: String? = nil) async throws -> String {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPrompt.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Le prompt ne peut pas être vide.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: instructions ?? Self.assistantInstructions
    )
    let response = try await session.respond(
      to: trimmedPrompt,
      options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 220)
    )
    return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func turnNotesIntoTasks(input: String) async throws -> [String] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Les notes à transformer ne peuvent pas être vides.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: """
      Tu transformes des notes courtes en tâches actionnables.
      Réponds en français.
      Chaque élément doit être une tâche courte, concrète et exécutable.
      N'ajoute aucune explication hors de la liste demandée.
      """
    )

    let response = try await session.respond(
      to: """
      Transforme ces notes en une liste de tâches actionnables.
      Ne garde que les tâches utiles et évite les doublons.

      Notes:
      \(trimmedInput)
      """,
      generating: [String].self,
      options: GenerationOptions(temperature: 0.1, maximumResponseTokens: 180)
    )

    return response.content
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func planAction(input: String, tasks: [AppleAITaskRecord]) async throws -> [String: Any?] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Le message ne peut pas être vide.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: """
      Tu es l'assistant local d'une app de to-do list iPhone.
      Réponds toujours en français.
      Ton ton doit être humain, fluide et naturel, comme une assistante personnelle attentive.
      N'utilise jamais de formulations mécaniques comme "Action effectuée", "Tâche créée", "Suppression réalisée" ou des structures trop techniques.
      Quand tu agis, assistantMessage doit déjà intégrer le résultat de manière naturelle, par exemple en expliquant simplement ce que tu viens de faire.
      Quand tu réponds sans agir, formule une réponse courte mais agréable à lire.
      Tu dois décider s'il faut simplement répondre à l'utilisateur ou déclencher une seule action locale.
      Les seules actions autorisées sont: none, create, edit, delete, complete.
      Utilise create si l'utilisateur veut créer une tâche.
      Utilise edit si l'utilisateur veut renommer ou reformuler une tâche existante.
      Utilise delete si l'utilisateur veut supprimer une tâche.
      Utilise complete si l'utilisateur veut marquer une tâche comme faite.
      Utilise none si l'utilisateur demande un résumé, une reformulation libre, des priorités, un avis ou toute autre réponse sans modification directe.
      Si une action vise une tâche existante, choisis taskIndex à partir de la liste fournie ci-dessous, avec un index commençant à 1.
      Si tu n'es pas assez sûr, renvoie action = none.
      assistantMessage doit être court, utile, contextuel et rédigé comme si tu parlais directement à l'utilisateur.
      Si l'utilisateur te demande une action, réponds comme quelqu'un qui vient de s'en charger.
      Exemples de style attendus:
      - "C'est fait, je l'ai ajoutée à ta liste."
      - "Je viens de reformuler cette tâche pour qu'elle soit plus claire."
      - "Je l'ai marquée comme terminée."
      - "Je te résume ça simplement."
      title est obligatoire pour create et edit, sinon null.
      taskIndex est obligatoire pour edit, delete et complete, sinon null.
      """
    )

    let schema = GenerationSchema(
      type: GeneratedContent.self,
      description: "Décision structurée de l'assistant pour répondre ou agir sur la to-do list.",
      properties: [
        .init(name: "action", description: "Une seule action parmi none, create, edit, delete, complete.", type: String.self),
        .init(name: "assistantMessage", description: "Réponse utilisateur courte en français.", type: String.self),
        .init(name: "taskIndex", description: "Index 1-based d'une tâche existante si nécessaire, sinon null.", type: Int?.self),
        .init(name: "title", description: "Titre final de la tâche à créer ou du nouveau titre si edit, sinon null.", type: String?.self)
      ]
    )

    let response = try await session.respond(
      to: """
      Demande utilisateur:
      \(trimmedInput)

      Tâches actuelles:
      \(formatTasksForDecision(tasks))
      """,
      schema: schema,
      includeSchemaInPrompt: true,
      options: GenerationOptions(temperature: 0.1, maximumResponseTokens: 220)
    )

    let content = response.content
    let action = try content.value(String.self, forProperty: "action")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let assistantMessage = try content.value(String.self, forProperty: "assistantMessage")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let taskIndex = try content.value(Int?.self, forProperty: "taskIndex")
    let title = try content.value(String?.self, forProperty: "title")?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return [
      "action": normalizeAction(action),
      "assistantMessage": assistantMessage,
      "taskIndex": taskIndex,
      "title": title?.isEmpty == true ? nil : title
    ]
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func buildSummaryPrompt(from tasks: [AppleAITaskRecord]) -> String {
    """
    Résume la liste de tâches suivante en 3 à 5 lignes maximum.
    Mets d'abord les points importants, puis les éventuels blocages.

    Tâches:
    \(formatTasks(tasks))
    """
  }

  private static func buildPrioritiesPrompt(from tasks: [AppleAITaskRecord]) -> String {
    """
    À partir de la liste de tâches suivante, propose exactement 3 priorités du jour.
    Réponds avec 3 lignes courtes commençant chacune par "- ".
    Favorise les tâches non terminées, concrètes et à fort impact.

    Tâches:
    \(formatTasks(tasks))
    """
  }

  private static func buildRewritePrompt(for title: String) -> String {
    """
    Reformule cette tâche en une seule phrase courte, claire et actionnable.
    Retourne uniquement la tâche reformulée.

    Tâche:
    \(title.trimmingCharacters(in: .whitespacesAndNewlines))
    """
  }

  private static func formatTasks(_ tasks: [AppleAITaskRecord]) -> String {
    if tasks.isEmpty {
      return "- Aucune tâche"
    }

    return tasks
      .sorted {
        if $0.completed != $1.completed {
          return $0.completed == false
        }
        return $0.createdAt > $1.createdAt
      }
      .map { task in
        let status = task.completed ? "[x]" : "[ ]"
        return "\(status) \(task.title)"
      }
      .joined(separator: "\n")
  }

  private static func formatTasksForDecision(_ tasks: [AppleAITaskRecord]) -> String {
    if tasks.isEmpty {
      return "Aucune tâche."
    }

    return tasks.enumerated().map { index, task in
      let status = task.completed ? "faite" : "à faire"
      return "\(index + 1). [\(status)] \(task.title)"
    }
    .joined(separator: "\n")
  }

  private static func normalizeAction(_ action: String) -> String {
    switch action {
    case "create", "edit", "delete", "complete", "none":
      return action
    default:
      return "none"
    }
  }

  private static func message(for error: Error) -> String {
#if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      if let generationError = error as? LanguageModelSession.GenerationError {
        return generationError.errorDescription
          ?? generationError.failureReason
          ?? generationError.recoverySuggestion
          ?? "La génération locale a échoué."
      }
    }
#endif

    if let localizedError = error as? LocalizedError {
      return localizedError.errorDescription
        ?? localizedError.failureReason
        ?? localizedError.recoverySuggestion
        ?? error.localizedDescription
    }

    return error.localizedDescription
  }

#if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
    switch reason {
    case .deviceNotEligible:
      return "Cet appareil n'est pas compatible avec Apple Intelligence."
    case .appleIntelligenceNotEnabled:
      return "Apple Intelligence doit être activé sur l'iPhone."
    case .modelNotReady:
      return "Le modèle Apple local n'est pas encore prêt sur cet appareil."
    @unknown default:
      return "Apple Intelligence n'est pas disponible sur cet appareil pour une raison inconnue."
    }
  }
#endif
}
