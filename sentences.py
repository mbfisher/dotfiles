from collections.abc import Iterable


def sentences(tokens: Iterable[str]) -> Iterable[str]:
    sentences = []
    sentence = []
    word = ""
    for token in tokens:
        for char in token:
            if char == " " or char == "." or char == "!":
                sentence.append(word)
                word = ""
                if char == "." or char == "!":
                    sentences.append(" ".join(sentence).strip())
                    sentence = []
            else:
                word += char

    sentence.append(word)
    sentences.append(" ".join(sentence).strip())

    return sentences


if __name__ == "__main__":
    print(
        sentences(
            [
                "matthew this ",
                "is too easy.",
                "far too easy. your top of funnel is ",
                "shit!",
                "(this actually took me multiple attempts)",
            ]
        )
    )
