enum RealismLevel { veryReal, sortaReal, kindaReal }

extension RealismLevelPrompts on RealismLevel {
  String get label {
    switch (this) {
      case RealismLevel.veryReal:
        return 'Very Real';
      case RealismLevel.sortaReal:
        return 'Sorta Real';
      case RealismLevel.kindaReal:
        return 'Kinda Real';
    }
  }

  String get imagePrefix {
    switch (this) {
      case RealismLevel.veryReal:
        return 'A real photograph, captured on a professional DSLR camera '
            'with a 50mm lens, natural window lighting, realistic human '
            'skin texture and pores, true-to-life fabric and material '
            'textures, candid documentary photography style. This is NOT '
            'an illustration, NOT a cartoon, NOT anime, NOT a 3D render, '
            'NOT digital art, NOT CGI — it is an actual unedited photo. '
            'Subject: ';
      case RealismLevel.sortaReal:
        return 'A naturalistic photo-style image with realistic lighting '
            'and proportions, lightly polished like a professional '
            'lifestyle or advertising photo — not flat illustration, not '
            'cartoon, not anime. Subject: ';
      case RealismLevel.kindaReal:
        return 'A stylized but grounded image — semi-realistic rendering '
            'with natural proportions and lighting, similar to high-end '
            'concept art or a cinematic render, not a flat cartoon or '
            'anime style. Subject: ';
    }
  }

  String get videoPrefix {
    switch (this) {
      case RealismLevel.veryReal:
        return 'Photorealistic footage, shot on a professional cinema '
            'camera, natural lighting, real human skin texture, candid '
            'documentary style. This is NOT animation, NOT a cartoon, NOT '
            '3D render, NOT CGI — it is real filmed footage. ';
      case RealismLevel.sortaReal:
        return 'Naturalistic video footage with realistic motion and '
            'lighting, lightly polished like a professional lifestyle ad '
            '— not flat animation or cartoon style. ';
      case RealismLevel.kindaReal:
        return 'Stylized but grounded video — semi-realistic rendering '
            'with natural motion, similar to a high-end cinematic render, '
            'not flat cartoon or anime animation. ';
    }
  }
}
