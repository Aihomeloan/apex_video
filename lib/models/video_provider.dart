enum VideoProvider { gemini, minimax }

extension VideoProviderLabel on VideoProvider {
  String get label {
    switch (this) {
      case VideoProvider.gemini:
        return 'Gemini (Veo)';
      case VideoProvider.minimax:
        return 'MiniMax (Hailuo)';
    }
  }
}
