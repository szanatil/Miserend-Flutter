/// What a problem report says is wrong with a church's data (CONTEXT.md,
/// „Hibajelentés"). The API knows these three and nothing finer; anything else
/// is [other] (spec 0009, „Hibajelentés: az oldal").
enum ProblemType { wrongPosition, wrongMassTime, other }
